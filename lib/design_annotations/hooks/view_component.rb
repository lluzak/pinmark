# frozen_string_literal: true

module DesignAnnotations
  module Hooks
    # Prepended into ViewComponent::Base when the gem is present. Inert until
    # then. Mirrors the Phlex `Components::Base#around_template` hook by wrapping
    # `render_in`'s output in design-annotation markers.
    module ViewComponent
      def render_in(view_context, &)
        return super unless DesignAnnotations.active?

        component = self.class.name || "anonymous"
        source = DesignAnnotations::SourceLocator.for(self.class) || "unknown"

        DesignAnnotations::Wrapper.wrap(component:, source:) do
          super
        end
      end
    end
  end
end
