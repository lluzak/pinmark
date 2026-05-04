# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pinmark::Phlex do
  # Phlex is not a runtime dependency. We exercise the concern's
  # `around_template` against a stand-in component that mirrors the parts of
  # the Phlex API we depend on: `around_template` invocation, `raw`, `safe`,
  # and yielding the template body.
  # Stand-in for `Phlex::SGML`: provides `around_template` in a *module* so
  # that `Pinmark::Phlex#around_template`'s `super` call resolves up the
  # ancestor chain, matching how it works against real Phlex base classes.
  let(:phlex_base_module) do
    Module.new do
      def around_template
        yield
      end
    end
  end

  let(:component_class) do
    mod = phlex_base_module
    klass = Class.new do
      include mod

      def self.name
        "FakePhlexComponent"
      end

      def initialize
        @output = +""
      end

      def call
        around_template { @output << "<div>fake-phlex-body</div>" }
        @output
      end

      def raw(string) = @output << string

      def safe(string) = string
    end
    klass.include(Pinmark::Phlex)
    klass
  end

  before { allow(Rails.env).to receive(:development?).and_return(true) }

  context "with annotations active" do
    it "wraps the template body in begin/end markers" do
      Current.pinmark = Pinmark::Tracker.new

      output = component_class.new.call

      expect(output).to start_with("<!-- pinmark:begin")
      expect(output).to include('class="FakePhlexComponent"')
      expect(output).to include("<div>fake-phlex-body</div>")
      expect(output).to match(/<!-- pinmark:end id="[^"]+" -->\z/)
    ensure
      Current.pinmark = nil
    end

    it "registers a node with the tracker and exposes its id" do
      tracker = Pinmark::Tracker.new
      Current.pinmark = tracker

      component = component_class.new
      component.call

      expect(tracker.nodes).to contain_exactly(
        a_hash_including(component: "FakePhlexComponent")
      )
      expect(component.pinmark_id).to eq(tracker.nodes.first[:id])
    ensure
      Current.pinmark = nil
    end

    it "pops the tracker frame after the template renders" do
      tracker = Pinmark::Tracker.new
      Current.pinmark = tracker

      component_class.new.call

      expect(tracker.send(:stack)).to be_empty if tracker.respond_to?(:stack, true)
    ensure
      Current.pinmark = nil
    end
  end

  context "without an active tracker" do
    it "is a passthrough" do
      Current.pinmark = nil

      output = component_class.new.call

      expect(output).to eq("<div>fake-phlex-body</div>")
    end

    it "leaves pinmark_id nil" do
      Current.pinmark = nil

      component = component_class.new
      component.call

      expect(component.pinmark_id).to be_nil
    end
  end
end
