# frozen_string_literal: true

require "rails/generators/base"

module Pinmark
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Wire Pinmark into the host app: routes, importmap, layout reminders."

      def mount_engine
        route 'mount Pinmark::Engine, at: "/dev/pinmark" if Rails.env.local?'
      end

      def add_importmap_pin
        return unless File.exist?("config/importmap.rb")

        append_to_file "config/importmap.rb" do
          <<~RB

            # pinmark engine — Stimulus controller for the dev annotation overlay
            pin "controllers/pinmark_controller", to: "pinmark/pinmark_controller.js"
          RB
        end
      end

      def show_post_install_notes
        say "\nPinmark installed.", :green
        say <<~NOTES

          Next steps (manual):

          1. If you use Phlex, include the concern in your component base class
             so `<!-- pinmark:begin/end -->` markers wrap each render:

               class Components::Base < Phlex::HTML
                 include Pinmark::Phlex if Rails.env.development?
               end

          2. Render the activator + overlay partials in your dev-only layout
             sections (works in any Rails view — ERB, Phlex, or ViewComponent):

               <%= render "pinmark/activator" %>
               <%= render "pinmark/overlay" %>

             Wrap with the usual dev-only / tracker guard if desired:

               if Rails.env.development? && Current.pinmark.present?
                 render "pinmark/activator"
                 render "pinmark/overlay"
               end

          3. Add `attribute :pinmark` to your `Current` model and include
             `Pinmark::Session` in the controllers whose responses should
             support annotations (typically StorefrontController).

          4. Register the in-process MCP server with Claude Code:

               claude mcp add pinmark --transport http \\
                 http://localhost:PORT/dev/pinmark/annotations/mcp

          5. Webpack/yarn-based hosts (no importmap): add the engine as a
             `file:` dependency in your host's package.json, then import the
             Stimulus controller directly from the gem — do NOT copy the JS
             into the host. Example:

               # package.json
               "pinmark": "file:#{Pinmark::Engine.root}"

               # app/javascript/packs/your_pack.js
               import PinmarkController from 'pinmark/pinmark_controller'
               window.Stimulus.register('pinmark', PinmarkController)

             Run `yarn install` after adding the dependency. The engine is the
             single source of truth; updates flow through the symlink.

        NOTES
      end
    end
  end
end
