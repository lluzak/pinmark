# Pinmark

Pin-style UI annotations that flow into Claude Code via MCP.

![demo](docs/demo.gif)

## Why Pinmark?

You spot something off in the browser — a misaligned card, a copy bug, the wrong
shade of orange. Normally you'd switch contexts: open the editor, hunt for the
component, type the prompt, paste a screenshot, describe the spot.

Pinmark closes that loop. Click the element on the page, type the comment,
keep working. Claude Code reads the queue over MCP and edits the right file —
because each annotation already carries its source `file:line`, the component
class, and the DOM selector.

## What you get

- Floating "Enable annotations" activator that survives Turbo navigation.
- Click-to-pin overlay with popover, side panel, on-page pin markers, marquee
  select, hover label, and a dual-highlight context for component vs. element.
- `<!-- pinmark:begin/end -->` HTML markers around every Phlex / ViewComponent /
  ERB partial render — automatically.
- File-backed atomic queue. Survives reloads, no database needed.
- Rack-mountable MCP HTTP server, in-process with your Rails app.
- Four MCP tools so Claude Code can list, resolve, and clear annotations.

## Install

In the host app's `Gemfile`:

```ruby
group :development do
  gem "pinmark"
end
```

Then:

```bash
bundle install
bin/rails generate pinmark:install
```

The generator mounts `Pinmark::Engine` at `/dev/pinmark` (only when
`Rails.env.local?`) and pins the engine's Stimulus controller into your
importmap.

For webpack / esbuild hosts, the same controller is published as an exports map
in `package.json` — add `"pinmark": "*"` (or a `file:` path during local
development) to your `package.json` and import it from your Stimulus entry
point:

```js
import PinmarkController from "pinmark"
application.register("pinmark", PinmarkController)
```

## Configure

A few host touch-points stay manual because they live in host-owned classes.

1. **Current attribute** — pinmark stores the per-request tracker on
   `ActiveSupport::CurrentAttributes`:

   ```ruby
   class Current < ActiveSupport::CurrentAttributes
     attribute :pinmark
   end
   ```

2. **Controller** — include the session concern in any controller whose
   responses should support annotations:

   ```ruby
   class ApplicationController < ActionController::Base
     include Pinmark::Session
   end
   ```

3. **Layout** — render the activator + overlay near the bottom of `<body>` in
   your dev layout:

   ```erb
   <% if Rails.env.development? && Current.pinmark.present? %>
     <%= render "pinmark/activator" %>
     <%= render "pinmark/overlay" %>
   <% end %>
   ```

4. **Phlex base class (optional)** — only if your host uses Phlex:

   ```ruby
   class Components::Base < Phlex::HTML
     include Pinmark::Phlex if Rails.env.development?
   end
   ```

   ViewComponent and ERB partial wrapping are auto-applied at engine boot — no
   per-host wiring needed.

5. **Mount** — the install generator adds this, but for reference:

   ```ruby
   # config/routes.rb
   mount Pinmark::Engine, at: "/dev/pinmark" if Rails.env.local?
   ```

## Use

Visit any page in development. Click the floating "Enable annotations" button.
Hover any component or element, click to drop a pin, leave a comment, save.
Pins persist on the page and across navigation until they're addressed.

## Connect to Claude Code

```bash
claude mcp add pinmark --transport http \
  http://localhost:PORT/dev/pinmark/annotations/mcp
```

Tools exposed:

- `list_pending_annotations` — every open annotation, with `file:line`,
  component class, DOM selector, comment, and page path.
- `list_resolved_annotations` — annotations that were already addressed.
- `mark_addressed` — flip an annotation by `id`.
- `clear_addressed` — purge the resolved bucket.

After Claude Code makes the change, it calls `mark_addressed` and the pin
disappears from the page on the next reload.

## How it works

- Render hooks emit HTML comment markers (`<!-- pinmark:begin id=... -->` …
  `<!-- pinmark:end id=... -->`) around every component render.
- A per-request `Pinmark::Tracker` collects the parent/child hierarchy plus the
  source location for each marker.
- The Stimulus controller in the browser walks the DOM, resolves which
  component is under the cursor, draws highlights, and POSTs annotations to the
  engine's controller.
- Annotations are appended atomically to `tmp/pinmark/queue.json`.
- The MCP server reads the same JSON file and exposes the four tools listed
  above. Claude Code talks to your local Rails app directly — no separate
  process.

## Renderer support

| Renderer       | Wiring                                                      |
| -------------- | ----------------------------------------------------------- |
| Phlex          | `include Pinmark::Phlex` in your component base class       |
| ViewComponent  | Auto — `render_in` is prepended at engine boot              |
| ERB partial    | Auto — `render_partial_template` is prepended at engine boot |

## Development

```bash
git clone https://github.com/lluzak/pinmark.git
cd pinmark
bundle install
bundle exec rspec
```

Pull requests welcome. Please add specs for any new behavior and keep the diff
focused — Pinmark stays intentionally small.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
