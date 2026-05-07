# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pinmark::Session
end
