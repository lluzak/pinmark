# Configuration reference

Pinmark deliberately exposes a tiny surface — most behavior is gated on
`Rails.env.development?` and a per-request tracker. This doc lists every knob.

## Environment

Pinmark only activates when **all** of these are true:

1. `Rails.env.development?` returns true.
2. `defined?(Current) && Current.respond_to?(:pinmark)` (the host has the
   `Current` model wired up).
3. `Current.pinmark` is a `Pinmark::Tracker` instance (set by
   `Pinmark::Session#setup_pinmark`).

`Pinmark.active?` (in `lib/pinmark.rb`) is the canonical predicate. It runs on
every render, so it's deliberately cheap.

```ruby
def self.active?
  Rails.env.development? && tracker.present?
end
```

In production / staging / test (anything that's not `development`), every hook
short-circuits before allocating anything beyond the predicate call.

## Activation triggers

The `Pinmark::Session` concern decides per-request whether to allocate a
tracker. From `app/controllers/concerns/pinmark/session.rb`:

```ruby
def pinmark_enabled?
  return false unless Rails.env.development?

  params[:annotate] == "1" || cookies[:pinmark] == "1"
end
```

So a request is instrumented when:

- The user clicked the floating activator (sets `pinmark=1` cookie), **or**
- The URL carries `?annotate=1` (one-shot, useful for shared links).

Both checks are cheap and run before the tracker is allocated.

## Required host wiring

### 1. `Current` attribute

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :pinmark
end
```

Pinmark looks up `::Current.pinmark` (top-level constant). If your host stores
request-scoped data under a different name, Pinmark won't find it — there is
no override hook for this on purpose, since `Current` is the Rails 7+
convention.

### 2. Session concern

```ruby
class ApplicationController < ActionController::Base
  include Pinmark::Session
end
```

You can include it more selectively (e.g. only in `StorefrontController`) if
you want annotations limited to one part of the app.

### 3. Layout partials

```erb
<% if Rails.env.development? && Current.pinmark.present? %>
  <%= render "pinmark/activator" %>
  <%= render "pinmark/overlay" %>
<% end %>
```

The guard is optional — both partials are inert without a tracker — but
rendering them unconditionally still serializes a (tiny) JSON tree on every
request. The `if` keeps that out of the response when the user hasn't opted in.

### 4. Phlex include (only if you use Phlex)

```ruby
class Components::Base < Phlex::HTML
  include Pinmark::Phlex if Rails.env.development?
end
```

Required because Phlex doesn't expose a stable mount point that the gem can
prepend into at engine boot — the hook lives on your component base class.
ViewComponent and ERB partial wrapping are auto-applied.

### 5. Mount

```ruby
# config/routes.rb
mount Pinmark::Engine, at: "/dev/pinmark" if Rails.env.local?
```

`Rails.env.local?` is true in `development` and `test`. The engine path is
hard-coded in the generator at `/dev/pinmark`; you can mount it elsewhere if
you also tell Claude Code about it (`claude mcp add pinmark --transport http
http://localhost:PORT/your/path/annotations/mcp`).

## Asset wiring

Pinmark ships a single Stimulus controller. There are two delivery paths:

### Importmap (Rails default)

The install generator appends to `config/importmap.rb`:

```ruby
pin "controllers/pinmark_controller", to: "pinmark/pinmark_controller.js"
```

The engine adds its `app/javascript` directory to `config.assets.paths` so
sprockets / propshaft can serve it.

### Webpack / esbuild / Bun

The gem publishes a `package.json` with an `exports` map. Add it to your host:

```json
{
  "dependencies": {
    "pinmark": "*"
  }
}
```

(Use `"file:../path/to/pinmark"` while developing locally.) Then import:

```js
import PinmarkController from "pinmark"
application.register("pinmark", PinmarkController)
```

The single-file controller has no third-party JS dependencies — only Stimulus
itself, which your host already has if it's a Rails app using Hotwire.

## Queue file

- **Path:** `Rails.root.join("tmp/pinmark/queue.json")`.
- **Format:** JSON, `{ "annotations": [...] }`.
- **Concurrency:** writes are atomic (write to `.tmp` + rename).
- **Lifetime:** until you `clear_addressed` or delete the file.
- **Gitignore:** `tmp/` is gitignored by default in Rails apps.

There's no env var to relocate the queue today; the path is set in
`Pinmark::Mcp::Queue#initialize` and lives under `tmp/` so the host's
existing housekeeping (e.g. `bin/rails tmp:clear`) cleans it up.

## Production safety

Every entry point checks `Rails.env.development?` before doing anything:

| Surface                          | Production behavior |
|----------------------------------|---------------------|
| `Pinmark::Session#setup_pinmark` | `pinmark_enabled?` returns false; no tracker, no overhead. |
| `Pinmark::Wrapper.wrap`          | Tracker is nil; passes the block through unchanged. |
| `Pinmark::Phlex#around_template` | Tracker is nil; calls `super` with no markers. |
| `Pinmark::Hooks::ViewComponent`  | Tracker is nil; passes through to `super`. |
| `Pinmark::Hooks::ErbPartial`     | Tracker is nil; passes through to `super`. |
| Engine mount                     | Guarded by `Rails.env.local?` in the generator. |

If you're paranoid, scope the gem to the development group in your Gemfile —
the runtime guards then become belt-and-suspenders.
