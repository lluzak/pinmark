# frozen_string_literal: true

require "active_support/concern"
require "cgi"

module Pinmark
  # Concern intended to be `include`d into the host application's Phlex
  # component base class (typically `Components::Base`). Provides an
  # `around_template` override that pushes/pops the per-request tracker and
  # emits `<!-- pinmark:begin/end -->` markers around the component's
  # rendered HTML.
  #
  # Inert outside of development mode and when no tracker is set on the
  # current request, so it is safe to include unconditionally.
  module Phlex
    extend ActiveSupport::Concern

    included do
      attr_reader :pinmark_id

      def around_template(&)
        @pinmark_id = nil
        tracker = Rails.env.development? ? Pinmark.tracker : nil
        return super unless tracker

        source = Pinmark::SourceLocator.for(self.class) || "unknown"
        component_name = self.class.name || "anonymous"
        @pinmark_id = tracker.push(component: component_name, source:)
        parent_id = tracker.nodes.last[:parent_id]

        id_attr = Pinmark::Wrapper.escape(@pinmark_id)
        class_attr = Pinmark::Wrapper.escape(component_name)
        src_attr = Pinmark::Wrapper.escape(source)
        parent_attr = Pinmark::Wrapper.escape(parent_id)

        raw safe(%(<!-- pinmark:begin id="#{id_attr}" class="#{class_attr}" src="#{src_attr}" parent="#{parent_attr}" -->))
        super
        raw safe(%(<!-- pinmark:end id="#{id_attr}" -->))
      ensure
        tracker&.pop if @pinmark_id
      end
    end
  end
end
