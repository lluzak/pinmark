# frozen_string_literal: true

Rails.application.routes.draw do
  mount DesignAnnotations::Engine, at: "/dev/design_annotations"
end
