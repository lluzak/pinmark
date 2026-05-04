# Pinmark

[![CI](https://github.com/lluzak/pinmark/actions/workflows/ci.yml/badge.svg)](https://github.com/lluzak/pinmark/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/pinmark.svg)](https://rubygems.org/gems/pinmark)
[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A5%203.2-CC342D.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/rails-%E2%89%A5%207.1-CC0000.svg)](https://rubyonrails.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.txt)

Pin-style UI annotations that flow into Claude Code via MCP.

![demo](docs/demo.gif)

> **Status:** early but usable. API may shift before 1.0 — pin a version in
> your Gemfile.

## Table of contents

- [Why Pinmark?](#why-pinmark)
- [What you get](#what-you-get)
- [Quickstart](#quickstart)
- [Install](#install)
- [Configure](#configure)
- [Use](#use)
- [Connect to Claude Code](#connect-to-claude-code)
- [How it works](#how-it-works)
- [Renderer support](#renderer-support)
- [Documentation](#documentation)
- [Development](#development)
- [License](#license)

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

## Quickstart

```bash
# 1. Add the gem (development group)
bundle add pinmark --group development

# 2. Wire it into your app
bin/rails generate pinmark:install

# 3. Boot the server, then point Claude Code at the in-process MCP endpoint
bin/rails server
claude mcp add pinmark --transport http \
  http://localhost:3000/dev/pinmark/annotations/mcp

# 4. Open any page, click "Enable annotations", drop a pin, type a comment.
#    Then ask Claude Code: "list pending annotations and fix them."
```

The generator handles routes and importmap pinning. The remaining manual steps
(Current attribute, Session concern, layout partials, optional Phlex include)
are listed in [Configure](#configure).

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

1. **Current attribute** — Pinmark stores the per-request tracker on
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

Full configuration reference lives in [docs/configuration.md](docs/configuration.md).

## Use

Visit any page in development. Click the floating "Enable annotations" button.
Hover any component or element, click to drop a pin, leave a comment, save.
Pins persist on the page and across navigation until they're addressed.

Activation triggers:

- **Cookie** — `pinmark=1` (set by clicking the activator).
- **Query param** — `?annotate=1` for a one-off page.

Both checks live in `Pinmark::Session#pinmark_enabled?` and are gated on
`Rails.env.development?`, so production traffic is never instrumented.

## Connect to Claude Code

```bash
claude mcp add pinmark --transport http \
  http://localhost:PORT/dev/pinmark/annotations/mcp
```

Tools exposed:

| Tool | Purpose |
|------|---------|
| `list_pending_annotations` | Every open annotation with `file:line`, component class, DOM selector, comment, page path, and ancestry chain. |
| `list_resolved_annotations` | Annotations that have been addressed (audit / undo). |
| `mark_addressed` | Flip a single annotation by `id`. Idempotent. |
| `clear_addressed` | Purge the resolved bucket. |

After Claude Code makes the change, it calls `mark_addressed` and the pin
disappears from the page on the next reload.

Full schemas, sample payloads, and prompt patterns are in
[docs/mcp-tools.md](docs/mcp-tools.md).

## How it works

```
┌─────────────────────────────────────────────────────────────────┐
│  Browser                                                         │
│  ─────────                                                       │
│  Stimulus controller walks the DOM, parses pinmark markers,      │
│  draws highlights, captures comment + selector + node_id, and    │
│  POSTs to the engine.                                            │
└──────────┬──────────────────────────────────────────────▲────────┘
           │ POST /dev/pinmark/annotations                │
           ▼                                              │
┌─────────────────────────────────────────────────────────┴────────┐
│  Rails (host process)                                            │
│  ──────────────────────                                          │
│  Per-request Tracker collects parent/child render hierarchy.     │
│  Wrapper emits <!-- pinmark:begin/end --> around every render.   │
│  AnnotationsController appends to tmp/pinmark/queue.json         │
│  atomically.                                                     │
│  MCP HTTP server reads the same JSON file in-process.            │
└──────────┬───────────────────────────────────────────────────────┘
           │ MCP tool calls (HTTP)
           ▼
        Claude Code
```

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

A deeper walkthrough lives in [docs/architecture.md](docs/architecture.md).

## Renderer support

| Renderer       | Wiring                                                       |
| -------------- | ------------------------------------------------------------ |
| Phlex          | `include Pinmark::Phlex` in your component base class        |
| ViewComponent  | Auto — `render_in` is prepended at engine boot               |
| ERB partial    | Auto — `render_partial_template` is prepended at engine boot |

## Documentation

| Doc | What's in it |
|-----|--------------|
| [docs/architecture.md](docs/architecture.md) | End-to-end data flow, lifecycle of an annotation, file layout. |
| [docs/configuration.md](docs/configuration.md) | Every config knob, the `Pinmark.active?` predicate, environment behavior. |
| [docs/mcp-tools.md](docs/mcp-tools.md) | Full MCP tool reference: input schemas, sample output, prompt patterns. |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common gotchas and how to debug them. |
| [CHANGELOG.md](CHANGELOG.md) | Per-release notes. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Local dev loop, test layout, PR expectations. |

## Development

```bash
git clone https://github.com/lluzak/pinmark.git
cd pinmark
bundle install
bundle exec rspec
```

Pull requests welcome. Please add specs for any new behavior and keep the diff
focused — Pinmark stays intentionally small. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the full loop.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
