# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pinmark::Tracker do
  subject(:tracker) { described_class.new }

  describe "#push / #pop" do
    it "assigns sequential ids and tracks parent/child relationships" do
      root_id = tracker.push(component: "Outer", source: "outer.rb:1")
      child_id = tracker.push(component: "Inner", source: "inner.rb:2")
      tracker.pop
      tracker.pop

      expect(tracker.nodes).to contain_exactly(
        a_hash_including(id: root_id, component: "Outer", parent_id: nil, source: "outer.rb:1"),
        a_hash_including(id: child_id, component: "Inner", parent_id: root_id, source: "inner.rb:2")
      )
    end

    it "raises if pop is called with an empty stack" do
      expect { tracker.pop }.to raise_error(Pinmark::Tracker::StackUnderflowError)
    end
  end

  describe "#tree" do
    it "returns a nested hierarchy preserving render order" do
      a = tracker.push(component: "A", source: "a.rb:1")
      b = tracker.push(component: "B", source: "b.rb:1")
      tracker.pop
      c = tracker.push(component: "C", source: "c.rb:1")
      tracker.pop
      tracker.pop

      tree = tracker.tree

      expect(tree).to match([
                              a_hash_including(
                                id: a, component: "A",
                                children: match([
                                                  a_hash_including(id: b, component: "B", children: []),
                                                  a_hash_including(id: c, component: "C", children: [])
                                                ])
                              )
                            ])
    end

    it "returns a valid hierarchy when called mid-render with the stack still open" do
      tracker.push(component: "A", source: "a.rb:1")
      tracker.push(component: "B", source: "b.rb:1")
      # do NOT pop — simulate calling tree while inside a render
      tree = tracker.tree

      expect(tree).to match([
                              a_hash_including(
                                component: "A",
                                children: match([a_hash_including(component: "B", children: [])])
                              )
                            ])
    end
  end
end
