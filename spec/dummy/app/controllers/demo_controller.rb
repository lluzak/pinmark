# frozen_string_literal: true

class DemoController < ApplicationController
  layout "application"

  def index; end

  def erb; end

  def view_component; end

  def phlex
    render DemoView.new
  end
end
