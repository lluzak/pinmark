# frozen_string_literal: true

module Pinmark
  # Inline CSS used by the engine's UI partials. Kept in Ruby so the partials
  # stay free of large heredoc blocks and the styles can be reused across
  # render contexts without depending on the asset pipeline.
  module Stylesheets
    ACTIVATOR = <<~CSS
      .pinmark-activator {
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
      .pinmark-activator:hover { background: #374151; }
      .pinmark-activator.is-on { background: #f97316; color: #111; border-color: #f97316; }
      .pinmark-activator.is-on:hover { background: #ea580c; }
    CSS

    ACTIVATOR_SCRIPT = <<~JS
      (function() {
        var btn = document.getElementById('pinmark-activator');
        if (!btn) return;
        btn.addEventListener('click', function() {
          var on = document.cookie.split('; ').some(function(c) { return c.indexOf('pinmark=1') === 0; });
          if (on) {
            document.cookie = 'pinmark=; path=/; max-age=0';
          } else {
            document.cookie = 'pinmark=1; path=/; max-age=2592000';
          }
          window.location.reload();
        });
      })();
    JS

    OVERLAY = <<~CSS
      .pinmark-toggle { position: fixed; bottom: 12px; right: 12px; z-index: 99999; padding: 6px 10px; background: #111; color: #fff; border: 0; border-radius: 6px; font: 12px sans-serif; cursor: pointer; }
      .pinmark-toggle.is-active { background: #f97316; color: #111; }
      .pinmark-mode { position: fixed; bottom: 12px; right: 124px; z-index: 99999; padding: 6px 10px; background: #1f2937; color: #fff; border: 0; border-radius: 6px; font: 12px sans-serif; cursor: pointer; }
      .pinmark-mode.is-element { background: #38bdf8; color: #0c1f2e; }
      .pinmark-panel { position: fixed; top: 12px; right: 12px; max-width: 320px; max-height: 70vh; overflow: auto; background: rgba(17,17,17,.92); color: #fff; padding: 12px; border-radius: 8px; font: 12px/1.4 sans-serif; z-index: 99999; display: none; }
      .pinmark-panel.is-open { display: block; }
      .pinmark-highlight { outline: 2px solid #f97316 !important; outline-offset: -2px; cursor: crosshair; }
      .pinmark-highlight-tag { outline: 2px dashed #38bdf8 !important; }
      .pinmark-highlight-context { outline: 2px dotted rgba(249,115,22,.55) !important; outline-offset: -2px; }
      .pinmark-popover { position: fixed; z-index: 99999; background: #111; color: #fff; padding: 8px; border-radius: 6px; min-width: 220px; }
      .pinmark-popover textarea { width: 100%; min-height: 60px; box-sizing: border-box; background: #1f2937; color: #fff; border: 1px solid #374151; border-radius: 4px; padding: 6px; font: 12px/1.4 sans-serif; resize: vertical; }
      .pinmark-popover textarea::placeholder { color: #9ca3af; }
      .pinmark-popover textarea:focus { outline: none; border-color: #38bdf8; }
      .pinmark-popover-actions { display: flex; gap: 6px; margin-top: 6px; }
      .pinmark-popover-actions button { padding: 4px 10px; background: #1f2937; color: #fff; border: 1px solid #374151; border-radius: 4px; font: 12px sans-serif; cursor: pointer; }
      .pinmark-popover-actions button:hover { background: #374151; }
      .pinmark-popover-actions button:first-child { background: #f97316; border-color: #f97316; color: #111; }
      .pinmark-popover-actions button:first-child:hover { background: #ea580c; }
      .pinmark-popover-header { font: 600 12px sans-serif; color: #fff; margin-bottom: 6px; line-height: 1.3; word-break: break-word; }
      .pinmark-popover-header .mcp-source { display: block; font-weight: 400; opacity: .75; font-size: 11px; }
      .pinmark-popover-header .mcp-selector { display: block; font-weight: 400; color: #38bdf8; font-size: 11px; word-break: break-all; }
      .pinmark-popover-debug { margin-top: 6px; color: #ddd; font: 11px sans-serif; }
      .pinmark-popover-debug summary { cursor: pointer; user-select: none; opacity: .7; }
      .pinmark-popover-debug summary:hover { opacity: 1; }
      .pinmark-popover-debug pre { margin: 6px 0 0; padding: 6px; background: rgba(255,255,255,.05); border-radius: 4px; white-space: pre-wrap; word-break: break-word; max-height: 160px; overflow: auto; font: 10px/1.4 ui-monospace, monospace; }
      .pinmark-label { position: fixed; z-index: 99999; padding: 2px 6px; background: #111; color: #fff; font: 11px sans-serif; border-radius: 4px; pointer-events: none; max-width: 360px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .pinmark-label.is-tag { background: #38bdf8; color: #0c1f2e; }
      .pinmark-markers { position: absolute; top: 0; left: 0; pointer-events: none; z-index: 99998; }
      .pinmark-marker { position: absolute; pointer-events: auto; transform: translate(-50%, -50%); width: 22px; height: 22px; border-radius: 50%; background: #f97316; color: #111; border: 2px solid #fff; box-shadow: 0 1px 4px rgba(0,0,0,.4); font: 600 11px sans-serif; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; padding: 0; }
      .pinmark-marker:hover { transform: translate(-50%, -50%) scale(1.15); }
      .pinmark-marker.is-resolved { background: #34d399; opacity: .75; }
      .pinmark-marquee { position: absolute; z-index: 99998; border: 1.5px dashed #f97316; background: rgba(249,115,22,.12); pointer-events: none; }
      .pinmark-panel-header { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 4px; }
      .pinmark-panel-collapse { background: transparent; color: #fff; border: 0; cursor: pointer; padding: 0 6px; font: 14px sans-serif; opacity: .6; }
      .pinmark-panel-collapse:hover { opacity: 1; }
      .pinmark-panel.is-collapsed { max-height: none; padding: 8px 12px; overflow: hidden; }
    CSS
  end
end
