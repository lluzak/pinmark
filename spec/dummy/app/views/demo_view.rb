# frozen_string_literal: true

class DemoView < Phlex::HTML
  include Pinmark::Phlex

  def view_template
    section(class: "stack") do
      h2 { "Phlex view" }
      render DemoCard.new(title: "Phlex card 1", body: "Hello from Phlex.")
      render DemoCard.new(title: "Phlex card 2", body: "Annotate me.")
    end
  end

  class DemoCard < Phlex::HTML
    include Pinmark::Phlex

    def initialize(title:, body:)
      @title = title
      @body = body
    end

    def view_template
      article(class: "card") do
        h3 { @title }
        p { @body }
      end
    end
  end
end
