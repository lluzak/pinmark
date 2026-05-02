# frozen_string_literal: true

module Pinmark
  # Wraps each request in a tracker so the Phlex/ViewComponent/ERB hooks can
  # push/pop nodes. Activated by the `?annotate=1` query string or the
  # `pinmark=1` cookie set by the activator partial.
  #
  # Include this in any host controller whose responses should support
  # annotations (typically the storefront base controller).
  module Session
    extend ActiveSupport::Concern

    included do
      around_action :setup_pinmark, if: :pinmark_enabled?
    end

    private

    def pinmark_enabled?
      return false unless Rails.env.development?

      params[:annotate] == "1" || cookies[:pinmark] == "1"
    end

    def setup_pinmark
      Current.pinmark = Pinmark::Tracker.new
      yield
    ensure
      Current.pinmark = nil
    end
  end
end
