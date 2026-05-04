# Architecture

Pinmark runs entirely inside your Rails dev process. There is no sidecar, no
database, no background worker. This doc traces a single annotation from the
moment a render hook fires to the moment Claude Code edits the source file.

## Components at a glance

```
lib/pinmark/
├── tracker.rb            # per-request render hierarchy + id generator
├── source_locator.rb     # class -> file:line resolver (Method#source_location)
├── wrapper.rb            # emits <!-- pinmark:begin/end --> markers
├── phlex.rb              # ActiveSupport::Concern for Phlex base classes
├── hooks/
│   ├── view_component.rb # prepended into ViewComponent::Base#render_in
│   └── erb_partial.rb    # prepended into ActionView::PartialRenderer
├── stylesheets.rb        # ships the activator/overlay CSS as a string constant
└── mcp/
    ├── queue.rb          # atomic JSON read/write at tmp/pinmark/queue.json
    ├── server.rb         # MCP::Server + tool registration
    ├── rack_app.rb       # Rack adapter mounted under the engine
    └── tools/
        ├── list_pending.rb
        ├── list_resolved.rb
        ├── mark_addressed.rb
        └── clear_addressed.rb

app/
├── controllers/pinmark/
│   ├── annotations_controller.rb   # POST /annotations, GET index, DELETE
│   └── application_controller.rb
├── controllers/concerns/pinmark/
│   └── session.rb                  # around_action -> Tracker.new per request
├── javascript/pinmark/
│   └── pinmark_controller.js       # Stimulus controller (overlay/popover/pins)
└── views/pinmark/
    ├── _activator.html.erb         # floating Enable/Disable button
    └── _overlay.html.erb           # Stimulus root + JSON tree + CSS
```

## Lifecycle of an annotation

### 1. Request enters

The host's `ApplicationController` includes `Pinmark::Session`. Its
`around_action :setup_pinmark` checks `pinmark_enabled?` (cookie or
`?annotate=1` query param, gated on `Rails.env.development?`). If enabled, it
sets `Current.pinmark = Pinmark::Tracker.new` for the duration of the
request and clears it afterwards.

The tracker is just an in-memory list of nodes plus a stack:

```ruby
{ id: "pm-1", component: "Storefront::Cart", source: "app/components/cart.rb:14", parent_id: nil }
```

### 2. Renders fire, hooks emit markers

Whenever the host renders a component, the matching hook runs:

| Renderer      | Hook                                                | Where         |
|---------------|-----------------------------------------------------|---------------|
| Phlex         | `Pinmark::Phlex#around_template`                    | `included` block on the host's component base class |
| ViewComponent | `Pinmark::Hooks::ViewComponent#render_in`           | Prepended into `ViewComponent::Base` at engine boot |
| ERB partial   | `Pinmark::Hooks::ErbPartial#render_partial_template`| Prepended into `ActionView::PartialRenderer`        |

All three converge on `Pinmark::Wrapper.wrap(component:, source:) { … }`,
which:

1. `tracker.push` allocates an id (`pm-N`) and records the parent.
2. The block runs and produces the actual HTML.
3. The output is bracketed with HTML comment markers:

   ```html
   <!-- pinmark:begin id="pm-3" class="Storefront::Cart" src="app/components/cart.rb:14" parent="pm-2" -->
     ...real component HTML...
   <!-- pinmark:end id="pm-3" -->
   ```

4. `tracker.pop` runs in `ensure`, even if the render raised.

When `Pinmark.active?` is false (production, or no tracker on the request),
`wrap` is a passthrough — zero allocation overhead beyond the predicate check.

### 3. Overlay renders alongside the page

The host's layout renders `pinmark/_activator` and `pinmark/_overlay`. The
overlay partial serializes `Current.pinmark.tree` into a `<script
type="application/json">` block and mounts the Stimulus controller.

### 4. Browser side: Stimulus controller wires everything up

`app/javascript/pinmark/pinmark_controller.js`:

- Parses the JSON tree.
- Walks the DOM at boot to associate every `<!-- pinmark:begin -->` marker
  with the next sibling element (its "anchor"), then attaches metadata
  (`pm-id`, `pm-class`, `pm-src`, `pm-parent`).
- Listens for hover / click and draws the highlight ring + label.
- On click, opens the popover, captures the comment, computes a relative DOM
  selector, and POSTs to `POST /dev/pinmark/annotations` with the comment,
  selector, captured node id, and a snapshot of the tree.
- Survives Turbo navigation by re-mounting on `turbo:load`.

### 5. Server side: queue write

`Pinmark::AnnotationsController#create`:

- Flattens the posted tree, builds an ancestry chain by walking `parent_id`s.
- Generates a UUID for the new annotation entry.
- Calls `Pinmark::Mcp::Queue#write` to atomically append to
  `tmp/pinmark/queue.json`.

The queue file shape:

```json
{
  "annotations": [
    {
      "id": "uuid",
      "status": "pending",
      "received_at": "2026-05-04T12:00:00Z",
      "page_path": "/cart",
      "component": "Storefront::Cart",
      "source": "app/components/cart.rb:14",
      "node_id": "pm-3",
      "selector": "ul > li:nth-child(2) > button",
      "text_excerpt": "Remove",
      "comment": "this button should be red",
      "captured_at": "2026-05-04T11:59:58Z",
      "ancestry": [
        { "id": "pm-1", "component": "Storefront::Layout", "source": "..." },
        { "id": "pm-2", "component": "Storefront::Cart::Item", "source": "..." },
        { "id": "pm-3", "component": "Storefront::Cart", "source": "..." }
      ]
    }
  ]
}
```

`Pinmark::Mcp::Queue` writes via the standard write-temp-and-rename pattern,
so partial writes can never corrupt the file.

### 6. Claude Code calls the MCP server

The same Rails process serves the MCP HTTP endpoint at
`/dev/pinmark/annotations/mcp`. `Pinmark::Mcp::RackApp` wraps
`Pinmark::Mcp::Server`, which registers the four tools and passes a freshly
opened `Pinmark::Mcp::Queue` in `server_context`.

Claude Code's typical sequence:

```text
list_pending_annotations
  -> read each entry's source field, jump to the file
  -> apply the fix
mark_addressed(id: "<uuid>")
  -> annotation moves from pending to addressed
```

On the next page load, the Stimulus controller's `GET /dev/pinmark/annotations`
returns the updated set; pins for addressed annotations don't re-render.

### 7. Cleanup

`clear_addressed` empties the `addressed` bucket when you want to forget the
audit trail. Otherwise the file grows slowly — it lives in `tmp/pinmark/`,
which is gitignored.

## Why HTML comment markers?

Markers are invisible text nodes — they survive every CSS layout, get cloned
with `innerHTML`, don't perturb selectors, and can be read by the browser at
any depth. Walking the DOM once at boot to pair markers with their next
sibling element is O(n) and lets the controller answer "what component is
under the cursor?" in constant time after that.

The `<!-- ... -->` form (rather than data attributes on a wrapper element) is
deliberate: it avoids changing the DOM structure of the host app's components.
A `<div data-pm-id="...">` wrapper would break flex / grid / table layouts.

## Why a file-backed queue instead of a database?

- Zero schema migration — Pinmark drops in.
- No coordination with the host's connection pool.
- The queue is tiny (kilobytes) and fully local; SQLite would be overkill.
- A flat JSON file is trivially `cat`-able when debugging.

## Why in-process MCP?

Running the MCP server inside the Rails process means it shares the same
file system view as the controller doing the writes — no race window, no
"which process owns the queue" question. It also means there's nothing to
start, supervise, or stop independently of `bin/rails server`.
