# frozen_string_literal: true

module DesignAnnotations
  class Activator < ::Phlex::HTML
    STYLESHEET = <<~CSS
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

    TOGGLE_SCRIPT = <<~JS
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

    def view_template
      enabled = DesignAnnotations.tracker.present?
      css_class = enabled ? "design-annotation-activator is-on" : "design-annotation-activator"

      button(type: "button", id: "design-annotation-activator", class: css_class) do
        enabled ? "Disable annotations" : "Enable annotations"
      end
      style { raw safe(STYLESHEET) }
      script { raw safe(TOGGLE_SCRIPT) }
    end
  end
end
