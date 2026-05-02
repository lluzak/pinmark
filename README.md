# Pinmark

Pinmark — pin-style annotations for live UI feedback into Claude Code.

In-page design annotation tool for Rails apps. Adds a development-only overlay
that lets a designer click on any rendered Phlex / ViewComponent / ERB partial,
leave a comment, and have an AI assistant pick the comment up over MCP.

## Installation

In the host app's `Gemfile`:

```ruby
gem "pinmark", path: "/Users/you/private/pinmark", group: :development
```

Then:

```bash
bundle install
bin/rails generate pinmark:install
```

The generator:

- Mounts `Pinmark::Engine` at `/dev/pinmark` in `Rails.env.local?`.
- Pins the engine's Stimulus controller into your importmap.
- Prints follow-up instructions for the parts that have to be wired by hand.

## Manual wiring

The engine is intentionally minimal — a few host touch-points remain manual
because they live in host-owned classes:

1. **Current attributes** — the per-request tracker lives on
   `ActiveSupport::CurrentAttributes`:

   ```ruby
   class Current < ActiveSupport::CurrentAttributes
     attribute :pinmark
   end
   ```

2. **Layout** — render the activator + overlay partials near the bottom of
   `<body>`. The partials are plain ERB so they work in any host (ERB,
   Phlex, ViewComponent, mixed):

   ```erb
   <% if Rails.env.development? && Current.pinmark.present? %>
     <%= render "pinmark/activator" %>
     <%= render "pinmark/overlay" %>
   <% end %>
   ```

   From a Phlex view the same string-path render works:

   ```ruby
   if Rails.env.development? && Current.pinmark.present?
     render "pinmark/activator"
     render "pinmark/overlay"
   end
   ```

3. **Controllers** — include the session concern in the controllers whose
   responses should support annotations:

   ```ruby
   class StorefrontController < ApplicationController
     include Pinmark::Session
   end
   ```

4. **Phlex base class (optional)** — only if your host uses Phlex. Include
   the concern in your component base class so each component render is
   wrapped in `<!-- pinmark:begin/end -->` markers. Hosts without Phlex
   skip this step entirely:

   ```ruby
   class Components::Base < Phlex::HTML
     include Pinmark::Phlex if Rails.env.development?
   end
   ```

   `Pinmark::Phlex` is the only Phlex-specific surface in the engine. The
   activator/overlay UI no longer requires Phlex to be present in the host.
   The ViewComponent integration is also opt-in and gated on
   `defined?(::ViewComponent::Base)`.

## MCP

The engine mounts an in-process MCP HTTP endpoint at
`/dev/pinmark/annotations/mcp`. Register it with Claude Code:

```bash
claude mcp add pinmark --transport http \
  http://localhost:4500/dev/pinmark/annotations/mcp
```

Tools exposed:

- `list_pending_annotations`
- `mark_addressed`
- `clear_addressed`

## Development

```bash
cd ~/private/pinmark
bundle install
bin/rspec
```
