# frozen_string_literal: true

module Pinmark
  class Tracker
    class StackUnderflowError < StandardError
    end

    attr_reader :nodes

    def initialize
      @nodes = []
      @stack = []
      @counter = 0
    end

    def push(component:, source:)
      @counter += 1
      id = "pm-#{@counter}"
      parent_id = @stack.last
      @nodes << { id:, component:, source:, parent_id: }
      @stack.push(id)
      id
    end

    def pop
      raise StackUnderflowError, "pinmark stack underflow" if @stack.empty?

      @stack.pop
    end

    def tree
      by_parent = @nodes.group_by { |node| node[:parent_id] }
      build = lambda { |parent_id|
        (by_parent[parent_id] || []).map do |node|
          node.merge(children: build.call(node[:id]))
        end
      }
      build.call(nil)
    end
  end
end
