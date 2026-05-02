# frozen_string_literal: true

module Pinmark
  module Hooks
    # Prepended into ActionView::PartialRenderer.
    #
    # Rails 8.1 `render_partial_template(view, locals, template, layout, block)`
    # is private and returns an `ActionView::AbstractRenderer::RenderedTemplate`
    # whose `body` is the rendered HTML string. To preserve the contract for
    # callers (collection assembly, layout wrapping) the override re-wraps the
    # body and returns a fresh RenderedTemplate.
    module ErbPartial
      def render_partial_template(view, locals, template, layout, block)
        rendered = super
        return rendered unless Pinmark.active?
        return rendered unless rendered.respond_to?(:body) && rendered.respond_to?(:template)

        identifier = template.respond_to?(:identifier) ? template.identifier.to_s : template.to_s
        relative = relative_to_root(identifier)
        component = "partial:#{File.basename(relative)}"
        source = "#{relative}:1"

        wrapped_body = Pinmark::Wrapper.wrap(component:, source:) do
          rendered.body.to_s
        end

        ::ActionView::AbstractRenderer::RenderedTemplate.new(wrapped_body, rendered.template)
      end

      private

      def relative_to_root(identifier)
        Pathname.new(identifier).relative_path_from(Rails.root).to_s
      rescue ArgumentError
        identifier
      end
    end
  end
end
