---
title: Troubleshooting
layout: default
nav_order: 5
permalink: /troubleshooting/
---

# Troubleshooting

## "I clicked Enable annotations but nothing happens"

**Check the cookie.** Open DevTools → Application → Cookies. You should see
`pinmark=1` after clicking the activator. If not, the activator partial
probably didn't render — see [the next item](#the-activator-doesnt-render).

**Check the request headers.** The next request after clicking should carry
the cookie. If it does, but no overlay appears, the controller likely doesn't
include `Pinmark::Session`. Add `include Pinmark::Session` to
`ApplicationController`.

**Check `Current.pinmark`.** From `bin/rails console`:

```ruby
Current.respond_to?(:pinmark)
# => true (must be true)
```

If false, you haven't added the `attribute :pinmark` line to your `Current`
model — see [Configure → Current attribute](../README.md#configure).

## The activator doesn't render

The partial is guarded:

```erb
<% if Rails.env.development? && Current.pinmark.present? %>
  <%= render "pinmark/activator" %>
<% end %>
```

If you copy that snippet verbatim, the activator only appears **after** the
cookie / query param has flipped the tracker on for the first time. The
chicken-and-egg fix is to render the activator unconditionally on the first
visit, or to bootstrap with `?annotate=1`:

```
http://localhost:3000/?annotate=1
```

Once the cookie is set, subsequent requests render the full overlay.

Alternatively, render the activator unconditionally in development and let it
toggle the cookie:

```erb
<% if Rails.env.development? %>
  <%= render "pinmark/activator" %>
<% end %>
<% if Current.pinmark.present? %>
  <%= render "pinmark/overlay" %>
<% end %>
```

## "Stimulus controller not registered" in the console

Importmap hosts: confirm `config/importmap.rb` contains the pin appended by
the install generator:

```ruby
pin "controllers/pinmark_controller", to: "pinmark/pinmark_controller.js"
```

Then in your `app/javascript/controllers/index.js` (or wherever you register
controllers), make sure `eagerLoadControllersFrom("controllers", application)`
or an explicit `application.register("pinmark", PinmarkController)` runs.

Webpack hosts: confirm `pinmark` is in `package.json` and that you import +
register it from your Stimulus entry point:

```js
import PinmarkController from "pinmark"
application.register("pinmark", PinmarkController)
```

## Pins land on the wrong element

The Stimulus controller pairs each `<!-- pinmark:begin -->` marker with the
**next sibling element**. Two common causes of mis-pairing:

1. **A renderer wraps content in a fragment.** ERB `content_tag` inside a
   `<%= capture do %>` works fine, but raw fragments with multiple top-level
   nodes confuse the pairing — only the first node gets the metadata. Wrap the
   component output in a single root element.

2. **A render hook wasn't applied.** Confirm the marker exists in `view-source`
   (browser → View Page Source). If you see the component's HTML but no
   `<!-- pinmark:begin -->` immediately before it, the hook didn't run for
   that path. For Phlex, that means the component's base class doesn't
   `include Pinmark::Phlex`.

## "frozen mode" / lockfile errors in CI

Make sure `Gemfile.lock` is committed and in sync with `pinmark.gemspec`. If
you add a development dependency, add it to the **Gemfile** (not the gemspec)
to avoid duplicated declarations — Bundler treats the same gem in both as
conflicting constraints. See `pinmark.gemspec` and `Gemfile` for the current
convention.

## MCP endpoint returns 404

Two failure modes:

1. **Engine not mounted.** Check `config/routes.rb` for `mount
   Pinmark::Engine`. The install generator adds it, guarded by
   `Rails.env.local?`.

2. **Wrong path.** The MCP endpoint is at the **engine path +
   `/annotations/mcp`**. With the default mount at `/dev/pinmark`, the URL is
   `http://localhost:3000/dev/pinmark/annotations/mcp` — note the trailing
   `mcp`. If you mounted at a different path, adjust accordingly.

Verify with curl:

```bash
curl -i http://localhost:3000/dev/pinmark/annotations
# 200 OK with a JSON body listing current annotations
```

## "ViewComponent::Base#render_in" warnings

Pinmark prepends into `ViewComponent::Base` inside an `ActiveSupport.on_load`
block. If you eager-load ViewComponent before Rails fires the `:view_component`
load hook (very rare — typically only in custom initializers that
`require "view_component"` themselves), the prepend may not run. Move the
require into an `after_initialize` block, or just delete it — Rails will load
ViewComponent on first use.

## Production guardrails

Pinmark gates everything on `Rails.env.development?`. To verify your
production deploy is genuinely inert:

```ruby
# Rails console (production)
Pinmark.active?              # => false
Current.pinmark              # => nil (or NoMethodError if you scoped Current)
```

If the gem is in your default Gemfile group rather than `:development`, the
runtime guards still apply, but pinning it to `:development` keeps the gem out
of your production bundle entirely. Recommended.

## Still stuck?

Open an issue with:

- Rails version (`bin/rails --version`)
- Ruby version (`ruby --version`)
- Renderer (`Phlex` / `ViewComponent` / `ERB`)
- Asset pipeline (`importmap` / `webpack` / `esbuild` / `propshaft`)
- Output of `cat tmp/pinmark/queue.json` (or "file does not exist")
- The first 50 lines of `view-source:` for the page where annotations don't
  work — we mostly need to see whether the markers are present.

<https://github.com/lluzak/pinmark/issues>
