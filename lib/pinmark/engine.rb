# frozen_string_literal: true

require "rails/engine"

module Pinmark
  class Engine < ::Rails::Engine
    isolate_namespace Pinmark

    initializer "pinmark.hooks" do
      ActiveSupport.on_load(:action_view) do
        require "pinmark/hooks/erb_partial"
        ActionView::PartialRenderer.prepend(Pinmark::Hooks::ErbPartial)
      end

      ActiveSupport.on_load(:view_component) do
        require "pinmark/hooks/view_component"
        ViewComponent::Base.prepend(Pinmark::Hooks::ViewComponent)
      end
    end

    # Make the engine's Stimulus controller available to host apps that use
    # `pin_all_from "app/javascript/controllers"`. We expose it under
    # `pinmark/` so the host can pin it explicitly without naming collisions.
    initializer "pinmark.assets" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.paths << root.join("app/javascript")
    end

    # Importmap-rails integration: register the engine's JS so importmap can
    # serve it under `pinmark/...`. The host pins it.
    initializer "pinmark.importmap", before: "importmap" do |app|
      next unless defined?(Importmap)

      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end
  end
end
