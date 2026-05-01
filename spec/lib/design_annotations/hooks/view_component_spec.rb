# frozen_string_literal: true

require "rails_helper"

RSpec.describe DesignAnnotations::Hooks::ViewComponent do
  # ViewComponent is not (yet) a runtime dependency. The hook will be prepended
  # automatically once the gem is installed; here we exercise the same code path
  # against a stand-in class that mirrors `ViewComponent::Base#render_in`.
  let(:stub_class) do
    klass = Class.new do
      def self.name
        "FakeViewComponent"
      end

      def render_in(_view_context)
        "<div>fake-component-body</div>"
      end
    end
    klass.prepend(DesignAnnotations::Hooks::ViewComponent)
    klass
  end

  before { allow(Rails.env).to receive(:development?).and_return(true) }

  context "with annotations active" do
    it "wraps render_in's output in begin/end markers" do
      Current.design_annotations = DesignAnnotations::Tracker.new

      output = stub_class.new.render_in(nil)

      expect(output).to start_with("<!-- design-annotation:begin")
      expect(output).to include('class="FakeViewComponent"')
      expect(output).to include("<div>fake-component-body</div>")
      expect(output).to end_with("-->")
      expect(output).to include("design-annotation:end")
    ensure
      Current.design_annotations = nil
    end

    it "registers a node with the tracker" do
      tracker = DesignAnnotations::Tracker.new
      Current.design_annotations = tracker

      stub_class.new.render_in(nil)

      expect(tracker.nodes).to contain_exactly(
        a_hash_including(component: "FakeViewComponent")
      )
    ensure
      Current.design_annotations = nil
    end
  end

  context "without an active tracker" do
    it "is a passthrough" do
      Current.design_annotations = nil

      output = stub_class.new.render_in(nil)

      expect(output).to eq("<div>fake-component-body</div>")
    end
  end
end
