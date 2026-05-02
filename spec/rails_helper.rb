# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"

abort("Rails is running in production mode!") if Rails.env.production?

require "rspec/rails"

# Files in spec/support are auto-loaded.
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Reset Current between examples so pinmark leakage between
  # tests can never silently pass.
  config.before do
    Current.reset
  end
end
