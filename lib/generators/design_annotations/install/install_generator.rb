# frozen_string_literal: true

require "rails/generators/base"

module DesignAnnotations
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Wire DesignAnnotations into the host app: routes, importmap, layout reminders."

      def mount_engine
        route 'mount DesignAnnotations::Engine, at: "/dev/design_annotations" if Rails.env.local?'
      end

      def add_importmap_pin
        return unless File.exist?("config/importmap.rb")

        append_to_file "config/importmap.rb" do
          <<~RB

            # design_annotations engine — Stimulus controller for the dev annotation overlay
            pin "controllers/annotation_overlay_controller", to: "design_annotations/annotation_overlay_controller.js"
          RB
        end
      end

      def show_post_install_notes
        say "\nDesignAnnotations installed.", :green
        say <<~NOTES

          Next steps (manual):

          1. If you use Phlex, include the concern in your component base class
             so `<!-- design-annotation:begin/end -->` markers wrap each render:

               class Components::Base < Phlex::HTML
                 include DesignAnnotations::Phlex if Rails.env.development?
               end

          2. Render the activator + overlay in your dev-only layout sections:

               if Rails.env.development? && Current.design_annotations.present?
                 render DesignAnnotations::Activator.new
                 render DesignAnnotations::AnnotationOverlay.new
               end

          3. Add `attribute :design_annotations` to your `Current` model and
             include `DesignAnnotations::Session` in the controllers whose
             responses should support annotations (typically StorefrontController).

          4. Register the in-process MCP server with Claude Code:

               claude mcp add design-annotations --transport http \\
                 http://localhost:PORT/dev/design_annotations/annotations/mcp

        NOTES
      end
    end
  end
end
