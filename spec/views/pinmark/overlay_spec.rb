# frozen_string_literal: true

require "rails_helper"

RSpec.describe "pinmark/_overlay", type: :view do
  after { Current.pinmark = nil }

  it "renders nothing when no tracker is set" do
    Current.pinmark = nil
    render partial: "pinmark/overlay"

    expect(rendered.strip).to eq("")
  end

  it "renders the Stimulus root and JSON tree when a tracker exists" do
    tracker = Pinmark::Tracker.new
    tracker.push(component: "Foo", source: "foo.rb:1")
    tracker.pop
    Current.pinmark = tracker

    render partial: "pinmark/overlay"

    expect(rendered).to include('data-controller="pinmark"')
    expect(rendered).to include('id="pinmark-tree"')
    expect(rendered).to include('"component":"Foo"')
  end

  it "includes a toggle button, panel target, popover template, and inline CSS" do
    tracker = Pinmark::Tracker.new
    tracker.push(component: "Foo", source: "foo.rb:1")
    tracker.pop
    Current.pinmark = tracker

    render partial: "pinmark/overlay"

    expect(rendered).to include('data-action="click-&gt;pinmark#toggle"').or include('data-action="click->pinmark#toggle"')
    expect(rendered).to include('data-pinmark-target="panel"')
    expect(rendered).to include('data-pinmark-target="popoverTemplate"')
    expect(rendered).to include(".pinmark-toggle")
  end

  it "preserves nested children in the JSON tree" do
    tracker = Pinmark::Tracker.new
    tracker.push(component: "Outer", source: "outer.rb:1")
    tracker.push(component: "Inner", source: "inner.rb:2")
    tracker.pop
    tracker.pop
    Current.pinmark = tracker

    render partial: "pinmark/overlay"

    expect(rendered).to match(/"component":"Outer".*"children":\[\{[^}]*"component":"Inner"/)
  end

  it "escapes </ in JSON to prevent script tag breakout" do
    tracker = Pinmark::Tracker.new
    allow(tracker).to receive(:tree).and_return([{ id: "phlex-1", component: "Hostile</script>", source: "x.rb:1", parent_id: nil, children: [] }])
    Current.pinmark = tracker

    render partial: "pinmark/overlay"
    json_body = rendered[%r{<script[^>]*id="pinmark-tree"[^>]*>(.*?)</script>}m, 1]

    expect(json_body).not_to include("</script>")
    expect(json_body).not_to include("</")
    expect(json_body).to include("Hostile")
  end
end
