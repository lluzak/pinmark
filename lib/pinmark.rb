# frozen_string_literal: true

require "pinmark/version"
require "pinmark/engine"
require "pinmark/stylesheets"
require "pinmark/tracker"
require "pinmark/source_locator"
require "pinmark/wrapper"
require "pinmark/phlex"
require "pinmark/hooks/erb_partial"
require "pinmark/hooks/view_component"
require "pinmark/mcp/queue"
require "pinmark/mcp/tools/list_pending"
require "pinmark/mcp/tools/list_resolved"
require "pinmark/mcp/tools/mark_addressed"
require "pinmark/mcp/tools/clear_addressed"
require "pinmark/mcp/server"
require "pinmark/mcp/rack_app"

module Pinmark
  # Whether the pinmark hooks should be active for the current request.
  # The host app sets Pinmark.tracker (typically per-request via the
  # Session concern) when the dev cookie / param toggles annotations on.
  #
  # We intentionally keep the predicate cheap so the wrapper / hooks can call it
  # on every render in development without measurable overhead.
  def self.active?
    Rails.env.development? && tracker.present?
  end

  def self.tracker
    return nil unless defined?(::Current) && ::Current.respond_to?(:pinmark)

    ::Current.pinmark
  end
end
