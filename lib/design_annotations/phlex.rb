# frozen_string_literal: true

require "active_support/concern"
require "cgi"

module DesignAnnotations
  # Concern intended to be `include`d into the host application's Phlex
  # component base class (typically `Components::Base`). Provides an
  # `around_template` override that pushes/pops the per-request tracker and
  # emits `<!-- design-annotation:begin/end -->` markers around the
  # component's rendered HTML.
  #
  # Inert outside of development mode and when no tracker is set on the
  # current request, so it is safe to include unconditionally.
  module Phlex
    extend ActiveSupport::Concern

    included do
      attr_reader :design_annotation_id

      def around_template(&)
        @design_annotation_id = nil
        tracker = Rails.env.development? ? DesignAnnotations.tracker : nil
        return super unless tracker

        source = DesignAnnotations::SourceLocator.for(self.class) || "unknown"
        component_name = self.class.name || "anonymous"
        @design_annotation_id = tracker.push(component: component_name, source:)
        parent_id = tracker.nodes.last[:parent_id]

        id_attr = DesignAnnotations::Wrapper.escape(@design_annotation_id)
        class_attr = DesignAnnotations::Wrapper.escape(component_name)
        src_attr = DesignAnnotations::Wrapper.escape(source)
        parent_attr = DesignAnnotations::Wrapper.escape(parent_id)

        raw safe(%(<!-- design-annotation:begin id="#{id_attr}" class="#{class_attr}" src="#{src_attr}" parent="#{parent_attr}" -->))
        super
        raw safe(%(<!-- design-annotation:end id="#{id_attr}" -->))
      ensure
        tracker&.pop if @design_annotation_id
      end
    end
  end
end
