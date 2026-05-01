# frozen_string_literal: true

require "rails_helper"

RSpec.describe DesignAnnotations::Activator, type: :view do
  after { Current.design_annotations = nil }

  it "renders an Enable label when no tracker is set" do
    Current.design_annotations = nil
    output = described_class.new.call

    expect(output).to include("Enable annotations")
    expect(output).not_to include("Disable annotations")
    expect(output).to include("design-annotation-activator")
  end

  it "renders a Disable label when a tracker is present" do
    Current.design_annotations = DesignAnnotations::Tracker.new
    output = described_class.new.call

    expect(output).to include("Disable annotations")
    expect(output).to include("is-on")
  end

  it "wires the inline cookie toggle script" do
    Current.design_annotations = nil
    output = described_class.new.call

    expect(output).to include("design_annotate=1")
    expect(output).to include("path=/")
    expect(output).to include("max-age=2592000")
    expect(output).to include("max-age=0")
    expect(output).to include("location.reload()")
  end
end
