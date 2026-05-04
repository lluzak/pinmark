# frozen_string_literal: true

require_relative "lib/pinmark/version"

Gem::Specification.new do |spec|
  spec.name        = "pinmark"
  spec.version     = Pinmark::VERSION
  spec.authors     = ["Przemyslaw Lusar"]
  spec.email       = ["lluzak@gmail.com"]
  spec.summary     = "Pin-style UI annotations that flow into Claude Code via MCP."
  spec.description = "Pinmark adds a dev-only floating overlay to any Rails app. " \
                     "Click a component or any element on the page, leave a comment, " \
                     "and Claude Code consumes the queue via MCP — closing the loop " \
                     "between visual feedback and source edits. Works with Phlex, " \
                     "ViewComponent, and ERB partials."
  spec.homepage    = "https://github.com/lluzak/pinmark"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*", "app/**/*", "config/**/*", "package.json"]
      .reject { |f| f.match(%r{^(spec|tmp|node_modules)/}) }
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "mcp", "~> 0.14"
end
