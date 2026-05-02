# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pinmark::SourceLocator do
  it "returns relative source path with line number for a known class" do
    location = described_class.for(Pinmark::Tracker)

    # Path is relative to Rails.root (the dummy app), so the engine source
    # appears as ../../lib/pinmark/tracker.rb:N or similar.
    expect(location).to match(%r{tracker\.rb:\d+\z})
  end

  it "returns nil for anonymous classes" do
    klass = Class.new
    expect(described_class.for(klass)).to be_nil
  end
end
