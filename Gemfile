# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in pinmark.gemspec.
gemspec

gem "puma"
gem "sqlite3"

group :development, :test do
  gem "rspec-rails", "~> 8.0"
  gem "phlex-rails", "~> 2.4"
  gem "view_component", "~> 4"
  gem "rack-test"
  gem "debug", platforms: %i[mri mingw mswin], require: "debug/prelude"
end
