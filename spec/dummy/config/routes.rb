# frozen_string_literal: true

Rails.application.routes.draw do
  mount Pinmark::Engine, at: "/dev/pinmark"
end
