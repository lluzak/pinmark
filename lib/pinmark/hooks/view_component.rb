# frozen_string_literal: true

module Pinmark
  module Hooks
    # Prepended into ViewComponent::Base when the gem is present. Inert until
    # then. Mirrors the Phlex `Components::Base#around_template` hook by wrapping
    # `render_in`'s output in pinmark markers.
    module ViewComponent
      def render_in(view_context, &)
        return super unless Pinmark.active?

        component = self.class.name || "anonymous"
        source = Pinmark::SourceLocator.for(self.class) || "unknown"

        Pinmark::Wrapper.wrap(component:, source:) do
          super
        end
      end
    end
  end
end
