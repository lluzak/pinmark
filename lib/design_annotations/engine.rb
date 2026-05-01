# frozen_string_literal: true

require "rails/engine"

module DesignAnnotations
  class Engine < ::Rails::Engine
    isolate_namespace DesignAnnotations

    initializer "design_annotations.hooks" do
      ActiveSupport.on_load(:action_view) do
        require "design_annotations/hooks/erb_partial"
        ActionView::PartialRenderer.prepend(DesignAnnotations::Hooks::ErbPartial)
      end

      ActiveSupport.on_load(:view_component) do
        require "design_annotations/hooks/view_component"
        ViewComponent::Base.prepend(DesignAnnotations::Hooks::ViewComponent)
      end
    end

    # Make the engine's Stimulus controller available to host apps that use
    # `pin_all_from "app/javascript/controllers"`. We expose it under
    # `design_annotations/` so the host can pin it explicitly without
    # naming collisions.
    initializer "design_annotations.assets" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.paths << root.join("app/javascript")
    end

    # Importmap-rails integration: register the engine's JS so importmap can
    # serve it under `design_annotations/...`. The host pins it.
    initializer "design_annotations.importmap", before: "importmap" do |app|
      next unless defined?(Importmap)

      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end
  end
end
