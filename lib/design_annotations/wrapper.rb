# frozen_string_literal: true

require "cgi"

module DesignAnnotations
  module Wrapper
    module_function

    # Wrap a block's HTML output in design-annotation begin/end markers, pushing
    # and popping the per-request tracker. When annotations are inactive (non-dev,
    # or no tracker) the block is invoked verbatim and its return value passes
    # through unchanged.
    #
    # The block must return a String (or something coercible via #to_s).
    def wrap(component:, source:)
      tracker = DesignAnnotations.tracker if Rails.env.development?
      return yield unless tracker

      id = tracker.push(component:, source:)
      parent_id = tracker.nodes.last[:parent_id]

      id_attr = escape(id)
      class_attr = escape(component)
      src_attr = escape(source)
      parent_attr = escape(parent_id)

      begin_marker = %(<!-- design-annotation:begin id="#{id_attr}" class="#{class_attr}" src="#{src_attr}" parent="#{parent_attr}" -->)
      end_marker = %(<!-- design-annotation:end id="#{id_attr}" -->)

      content = yield.to_s
      "#{begin_marker}#{content}#{end_marker}".html_safe
    ensure
      tracker&.pop if id
    end

    def escape(value)
      CGI.escapeHTML(value.to_s).gsub("--", "&#45;&#45;")
    end
  end
end
