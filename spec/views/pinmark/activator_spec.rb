# frozen_string_literal: true

require "rails_helper"

RSpec.describe "pinmark/_activator", type: :view do
  after { Current.pinmark = nil }

  it "renders an Enable label when no tracker is set" do
    Current.pinmark = nil
    render partial: "pinmark/activator"

    expect(rendered).to include("Enable annotations")
    expect(rendered).not_to include("Disable annotations")
    expect(rendered).to include("pinmark-activator")
  end

  it "renders a Disable label when a tracker is present" do
    Current.pinmark = Pinmark::Tracker.new
    render partial: "pinmark/activator"

    expect(rendered).to include("Disable annotations")
    expect(rendered).to include("is-on")
  end

  it "wires the inline cookie toggle onclick" do
    Current.pinmark = nil
    render partial: "pinmark/activator"

    expect(rendered).to include("pinmark=1")
    expect(rendered).to include("path=/")
    expect(rendered).to include("max-age=2592000")
    expect(rendered).to include("max-age=0")
    expect(rendered).to include("window.location.assign")
    expect(rendered).to include('data-turbo="false"')
    expect(rendered).to include("onclick=")
  end
end
