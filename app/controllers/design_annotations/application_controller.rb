# frozen_string_literal: true

module DesignAnnotations
  # Base controller for the engine. Inherits from `ActionController::Base`
  # directly (rather than the host's `ApplicationController`) to keep the
  # engine self-contained — host concerns like authentication / multi-tenancy
  # never run for the dev-only annotation endpoints.
  class ApplicationController < ::ActionController::Base
    skip_forgery_protection

    before_action :ensure_development!

    private

    def ensure_development!
      head(:not_found) unless Rails.env.development?
    end
  end
end
