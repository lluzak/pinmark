# frozen_string_literal: true

module DesignAnnotations
  # Wraps each request in a tracker so the Phlex/ViewComponent/ERB hooks can
  # push/pop nodes. Activated by the `?annotate=1` query string or the
  # `design_annotate=1` cookie set by `DesignAnnotations::Activator`.
  #
  # Include this in any host controller whose responses should support
  # annotations (typically the storefront base controller).
  module Session
    extend ActiveSupport::Concern

    included do
      around_action :setup_design_annotations, if: :design_annotations_enabled?
    end

    private

    def design_annotations_enabled?
      return false unless Rails.env.development?

      params[:annotate] == "1" || cookies[:design_annotate] == "1"
    end

    def setup_design_annotations
      Current.design_annotations = DesignAnnotations::Tracker.new
      yield
    ensure
      Current.design_annotations = nil
    end
  end
end
