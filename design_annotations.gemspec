# frozen_string_literal: true

require_relative "lib/design_annotations/version"

Gem::Specification.new do |spec|
  spec.name        = "design_annotations"
  spec.version     = DesignAnnotations::VERSION
  spec.authors     = ["Przemyslaw Lusar"]
  spec.email       = ["przemyslaw.lusar@easol.com"]
  spec.summary     = "In-page design annotation tool with MCP server, mountable as a Rails engine."
  spec.description = "Adds a development-only overlay that lets a designer annotate any " \
                     "rendered Phlex / ViewComponent / ERB partial. Annotations are pushed " \
                     "into a JSON queue served over MCP so an AI assistant can read and act " \
                     "on them in-process with the host Rails app."
  spec.homepage    = "https://github.com/lluzak/design_annotations"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |f|
      File.directory?(f)
    end
  end

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "mcp", "~> 0.14"
end
