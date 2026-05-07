# frozen_string_literal: true

class DemoCardComponent < ViewComponent::Base
  def initialize(title:, body:)
    super()
    @title = title
    @body = body
  end

  attr_reader :title, :body
end
