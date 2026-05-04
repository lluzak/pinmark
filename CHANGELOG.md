# Changelog

## 0.1.0 — Unreleased

Initial release.

- Phlex `around_template` hook via `Pinmark::Phlex` concern.
- ViewComponent `render_in` prepend hook (auto-applied when ViewComponent is loaded).
- ERB partial `render_partial_template` prepend hook.
- Activator + overlay ERB partials renderable in any Rails layout.
- Stimulus controller for hover targeting, popover comments, side panel, on-page pin markers, marquee select.
- File-backed atomic queue at `tmp/pinmark/queue.json`.
- Rack-mountable MCP HTTP server exposing `list_pending_annotations`, `list_resolved_annotations`, `mark_addressed`, `clear_addressed`.
