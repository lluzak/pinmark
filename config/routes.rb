# frozen_string_literal: true

DesignAnnotations::Engine.routes.draw do
  if Rails.env.local?
    resources :annotations, only: [:index, :create, :destroy]

    # MCP server mounted in-process so Claude Code can speak MCP directly
    # to the host Rails app. No separate Foreman/Overmind worker required.
    mount DesignAnnotations::Mcp::RackApp.new, at: "annotations/mcp"
  end
end
