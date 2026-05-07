# frozen_string_literal: true

Rails.application.routes.draw do
  mount Pinmark::Engine, at: "/dev/pinmark"

  root to: "demo#index"
  get "demo", to: "demo#index", as: :demo_home
  get "demo/erb", to: "demo#erb", as: :demo_erb
  get "demo/view_component", to: "demo#view_component", as: :demo_view_component
  get "demo/phlex", to: "demo#phlex", as: :demo_phlex

  # Serve the engine's Stimulus controller so the dummy app can load it as a
  # JS module without dragging in importmap-rails / sprockets / propshaft.
  get "_dummy_assets/pinmark_controller.js",
      to: "dev_assets#pinmark_controller",
      as: :pinmark_controller_asset
end
