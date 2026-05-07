# frozen_string_literal: true

require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

# Phlex / ViewComponent are dev-only deps of the engine so they're available
# in the test environment for component / hook specs.
require "phlex/rails"
require "view_component"

require "pinmark"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.consider_all_requests_local = true
    config.active_support.deprecation = :stderr
    config.secret_key_base = "dummy_secret_key_base_for_pinmark_engine_tests"

    # Skip ActiveRecord, ActiveJob, Mailer, ActiveStorage — engine doesn't need them.
    config.api_only = false

    # Tests need a writable host config root.
    config.root = File.expand_path("..", __dir__)
    config.autoload_paths << File.expand_path("../app/components", __dir__)
    config.autoload_paths << File.expand_path("../app/views", __dir__)

    # Allow the dev-server to bind any host (the dummy app is for local
    # browser testing only).
    config.hosts.clear if config.respond_to?(:hosts)
  end
end
