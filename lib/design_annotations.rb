# frozen_string_literal: true

require "design_annotations/version"
require "design_annotations/engine"
require "design_annotations/stylesheets"
require "design_annotations/tracker"
require "design_annotations/source_locator"
require "design_annotations/wrapper"
require "design_annotations/phlex"
require "design_annotations/hooks/erb_partial"
require "design_annotations/hooks/view_component"
require "design_annotations/mcp/queue"
require "design_annotations/mcp/tools/list_pending"
require "design_annotations/mcp/tools/mark_addressed"
require "design_annotations/mcp/tools/clear_addressed"
require "design_annotations/mcp/server"
require "design_annotations/mcp/rack_app"

module DesignAnnotations
  # Whether the design annotation hooks should be active for the current request.
  # The host app sets DesignAnnotations.tracker (typically per-request via the
  # Session concern) when the dev cookie / param toggles annotations on.
  #
  # We intentionally keep the predicate cheap so the wrapper / hooks can call it
  # on every render in development without measurable overhead.
  def self.active?
    Rails.env.development? && tracker.present?
  end

  def self.tracker
    return nil unless defined?(::Current) && ::Current.respond_to?(:design_annotations)

    ::Current.design_annotations
  end
end
