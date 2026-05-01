# DesignAnnotations

In-page design annotation tool for Rails apps. Adds a development-only overlay
that lets a designer click on any rendered Phlex / ViewComponent / ERB partial,
leave a comment, and have an AI assistant pick the comment up over MCP.

## Installation

In the host app's `Gemfile`:

```ruby
gem "design_annotations", path: "/Users/you/private/design_annotations", group: :development
```

Then:

```bash
bundle install
bin/rails generate design_annotations:install
```

The generator:

- Mounts `DesignAnnotations::Engine` at `/dev/design_annotations` in `Rails.env.local?`.
- Pins the engine's Stimulus controller into your importmap.
- Prints follow-up instructions for the parts that have to be wired by hand.

## Manual wiring

The engine is intentionally minimal — three host touch-points remain manual
because they live in host-owned classes:

1. **Phlex base class** — include the concern so each component render is
   wrapped in `<!-- design-annotation:begin/end -->` markers:

   ```ruby
   class Components::Base < Phlex::HTML
     include DesignAnnotations::Phlex if Rails.env.development?
   end
   ```

2. **Current attributes** — the per-request tracker lives on
   `ActiveSupport::CurrentAttributes`:

   ```ruby
   class Current < ActiveSupport::CurrentAttributes
     attribute :design_annotations
   end
   ```

3. **Layout** — render the activator + overlay near the bottom of `<body>`:

   ```ruby
   if Rails.env.development? && Current.design_annotations.present?
     render DesignAnnotations::Activator.new
     render DesignAnnotations::AnnotationOverlay.new
   end
   ```

4. **Controllers** — include the session concern in the controllers whose
   responses should support annotations:

   ```ruby
   class StorefrontController < ApplicationController
     include DesignAnnotations::Session
   end
   ```

## MCP

The engine mounts an in-process MCP HTTP endpoint at
`/dev/design_annotations/annotations/mcp`. Register it with Claude Code:

```bash
claude mcp add design-annotations --transport http \
  http://localhost:4500/dev/design_annotations/annotations/mcp
```

Tools exposed:

- `list_pending_annotations`
- `mark_addressed`
- `clear_addressed`

## Development

```bash
cd ~/private/design_annotations
bundle install
bin/rspec
```
