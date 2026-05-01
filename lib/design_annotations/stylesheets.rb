# frozen_string_literal: true

module DesignAnnotations
  # Inline CSS used by the engine's UI partials. Kept in Ruby so the partials
  # stay free of large heredoc blocks and the styles can be reused across
  # render contexts without depending on the asset pipeline.
  module Stylesheets
    ACTIVATOR = <<~CSS
      .design-annotation-activator {
        position: fixed;
        bottom: 12px;
        left: 12px;
        z-index: 99999;
        padding: 6px 10px;
        background: #1f2937;
        color: #fff;
        border: 1px solid #374151;
        border-radius: 6px;
        font: 12px sans-serif;
        cursor: pointer;
        box-shadow: 0 2px 6px rgba(0, 0, 0, 0.25);
      }
      .design-annotation-activator:hover { background: #374151; }
      .design-annotation-activator.is-on { background: #f97316; color: #111; border-color: #f97316; }
      .design-annotation-activator.is-on:hover { background: #ea580c; }
    CSS

    ACTIVATOR_SCRIPT = <<~JS
      (function() {
        var btn = document.getElementById('design-annotation-activator');
        if (!btn) return;
        btn.addEventListener('click', function() {
          var on = document.cookie.split('; ').some(function(c) { return c.indexOf('design_annotate=1') === 0; });
          if (on) {
            document.cookie = 'design_annotate=; path=/; max-age=0';
          } else {
            document.cookie = 'design_annotate=1; path=/; max-age=2592000';
          }
          window.location.reload();
        });
      })();
    JS

    OVERLAY = <<~CSS
      .design-annotation-toggle { position: fixed; bottom: 12px; right: 12px; z-index: 99999; padding: 6px 10px; background: #111; color: #fff; border: 0; border-radius: 6px; font: 12px sans-serif; cursor: pointer; }
      .design-annotation-toggle.is-active { background: #f97316; color: #111; }
      .design-annotation-mode { position: fixed; bottom: 12px; right: 124px; z-index: 99999; padding: 6px 10px; background: #1f2937; color: #fff; border: 0; border-radius: 6px; font: 12px sans-serif; cursor: pointer; }
      .design-annotation-mode.is-element { background: #38bdf8; color: #0c1f2e; }
      .design-annotation-panel { position: fixed; top: 12px; right: 12px; max-width: 320px; max-height: 70vh; overflow: auto; background: rgba(17,17,17,.92); color: #fff; padding: 12px; border-radius: 8px; font: 12px/1.4 sans-serif; z-index: 99999; display: none; }
      .design-annotation-panel.is-open { display: block; }
      .design-annotation-highlight { outline: 2px solid #f97316 !important; outline-offset: -2px; cursor: crosshair; }
      .design-annotation-highlight-tag { outline: 2px dashed #38bdf8 !important; }
      .design-annotation-highlight-context { outline: 2px dotted rgba(249,115,22,.55) !important; outline-offset: -2px; }
      .design-annotation-popover { position: fixed; z-index: 99999; background: #111; color: #fff; padding: 8px; border-radius: 6px; min-width: 220px; }
      .design-annotation-popover textarea { width: 100%; min-height: 60px; box-sizing: border-box; background: #1f2937; color: #fff; border: 1px solid #374151; border-radius: 4px; padding: 6px; font: 12px/1.4 sans-serif; resize: vertical; }
      .design-annotation-popover textarea::placeholder { color: #9ca3af; }
      .design-annotation-popover textarea:focus { outline: none; border-color: #38bdf8; }
      .design-annotation-popover-actions { display: flex; gap: 6px; margin-top: 6px; }
      .design-annotation-popover-actions button { padding: 4px 10px; background: #1f2937; color: #fff; border: 1px solid #374151; border-radius: 4px; font: 12px sans-serif; cursor: pointer; }
      .design-annotation-popover-actions button:hover { background: #374151; }
      .design-annotation-popover-actions button:first-child { background: #f97316; border-color: #f97316; color: #111; }
      .design-annotation-popover-actions button:first-child:hover { background: #ea580c; }
      .design-annotation-popover-header { font: 600 12px sans-serif; color: #fff; margin-bottom: 6px; line-height: 1.3; word-break: break-word; }
      .design-annotation-popover-header .mcp-source { display: block; font-weight: 400; opacity: .75; font-size: 11px; }
      .design-annotation-popover-header .mcp-selector { display: block; font-weight: 400; color: #38bdf8; font-size: 11px; word-break: break-all; }
      .design-annotation-popover-debug { margin-top: 6px; color: #ddd; font: 11px sans-serif; }
      .design-annotation-popover-debug summary { cursor: pointer; user-select: none; opacity: .7; }
      .design-annotation-popover-debug summary:hover { opacity: 1; }
      .design-annotation-popover-debug pre { margin: 6px 0 0; padding: 6px; background: rgba(255,255,255,.05); border-radius: 4px; white-space: pre-wrap; word-break: break-word; max-height: 160px; overflow: auto; font: 10px/1.4 ui-monospace, monospace; }
      .design-annotation-label { position: fixed; z-index: 99999; padding: 2px 6px; background: #111; color: #fff; font: 11px sans-serif; border-radius: 4px; pointer-events: none; max-width: 360px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .design-annotation-label.is-tag { background: #38bdf8; color: #0c1f2e; }
      .design-annotation-markers { position: absolute; top: 0; left: 0; pointer-events: none; z-index: 99998; }
      .design-annotation-marker { position: absolute; pointer-events: auto; transform: translate(-50%, -50%); width: 22px; height: 22px; border-radius: 50%; background: #f97316; color: #111; border: 2px solid #fff; box-shadow: 0 1px 4px rgba(0,0,0,.4); font: 600 11px sans-serif; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; padding: 0; }
      .design-annotation-marker:hover { transform: translate(-50%, -50%) scale(1.15); }
      .design-annotation-marker.is-resolved { background: #34d399; opacity: .75; }
      .design-annotation-marquee { position: absolute; z-index: 99998; border: 1.5px dashed #f97316; background: rgba(249,115,22,.12); pointer-events: none; }
      .design-annotation-panel-header { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 4px; }
      .design-annotation-panel-collapse { background: transparent; color: #fff; border: 0; cursor: pointer; padding: 0 6px; font: 14px sans-serif; opacity: .6; }
      .design-annotation-panel-collapse:hover { opacity: 1; }
      .design-annotation-panel.is-collapsed { max-height: none; padding: 8px 12px; overflow: hidden; }
    CSS
  end
end
