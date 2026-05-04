# Changelog

## 0.1.1 — 2026-05-04

- Fix gemspec missing `require_paths`, which prevented Bundler.require from auto-loading Pinmark in host apps.

## 0.1.0 — 2026-05-02

Initial release.

- Phlex `around_template` hook via `Pinmark::Phlex` concern.
- ViewComponent `render_in` prepend hook (auto-applied when ViewComponent is loaded).
- ERB partial `render_partial_template` prepend hook.
- Activator + overlay ERB partials renderable in any Rails layout.
- Stimulus controller for hover targeting, popover comments, side panel, on-page pin markers, marquee select.
- File-backed atomic queue at `tmp/pinmark/queue.json`.
- Rack-mountable MCP HTTP server exposing `list_pending_annotations`, `list_resolved_annotations`, `mark_addressed`, `clear_addressed`.
