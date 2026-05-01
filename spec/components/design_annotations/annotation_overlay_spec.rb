# frozen_string_literal: true

require "rails_helper"

RSpec.describe DesignAnnotations::AnnotationOverlay, type: :view do
  after { Current.design_annotations = nil }

  it "renders nothing when no tracker is set" do
    Current.design_annotations = nil
    expect(described_class.new.call).to eq("")
  end

  it "renders the Stimulus root and JSON tree when a tracker exists" do
    tracker = DesignAnnotations::Tracker.new
    tracker.push(component: "Foo", source: "foo.rb:1")
    tracker.pop
    Current.design_annotations = tracker

    output = described_class.new.call

    expect(output).to include('data-controller="annotation-overlay"')
    expect(output).to include('id="design-annotation-tree"')
    expect(output).to include('"component":"Foo"')
  end

  it "includes a toggle button, panel target, popover template, and inline CSS" do
    tracker = DesignAnnotations::Tracker.new
    tracker.push(component: "Foo", source: "foo.rb:1")
    tracker.pop
    Current.design_annotations = tracker

    output = described_class.new.call

    expect(output).to include('data-action="click->annotation-overlay#toggle"')
    expect(output).to include('data-annotation-overlay-target="panel"')
    expect(output).to include('data-annotation-overlay-target="popoverTemplate"')
    expect(output).to include(".design-annotation-toggle")
  end

  it "preserves nested children in the JSON tree" do
    tracker = DesignAnnotations::Tracker.new
    tracker.push(component: "Outer", source: "outer.rb:1")
    tracker.push(component: "Inner", source: "inner.rb:2")
    tracker.pop
    tracker.pop
    Current.design_annotations = tracker

    output = described_class.new.call

    expect(output).to match(/"component":"Outer".*"children":\[\{[^}]*"component":"Inner"/)
  end

  it "escapes </ in JSON to prevent script tag breakout" do
    tracker = DesignAnnotations::Tracker.new
    allow(tracker).to receive(:tree).and_return([{ id: "phlex-1", component: "Hostile</script>", source: "x.rb:1", parent_id: nil, children: [] }])
    Current.design_annotations = tracker

    output = described_class.new.call
    json_body = output[%r{<script[^>]*id="design-annotation-tree"[^>]*>(.*?)</script>}m, 1]

    expect(json_body).not_to include("</script>")
    expect(json_body).not_to include("</")
    expect(json_body).to include("Hostile")
  end
end
