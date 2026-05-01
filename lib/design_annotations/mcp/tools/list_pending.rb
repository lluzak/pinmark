# frozen_string_literal: true

require "json"
require "mcp"

module DesignAnnotations
  module Mcp
    module Tools
      def self.text_response(payload)
        ::MCP::Tool::Response.new([{ type: "text", text: JSON.pretty_generate(payload) }])
      end

      class ListPending < ::MCP::Tool
        tool_name "list_pending_annotations"
        description "Return every annotation in the queue with status='pending'. Each entry " \
                    "includes the source file:line, component class, page path, relative DOM " \
                    "selector (if any), the user's comment, and the entry id needed for " \
                    "mark_addressed."
        input_schema(properties: {})

        class << self
          def call(server_context:)
            queue = server_context.fetch(:queue)
            pending = queue.pending.map do |entry|
              {
                "id" => entry["id"],
                "node_id" => entry["node_id"],
                "component" => entry["component"],
                "source" => entry["source"],
                "selector" => entry["selector"],
                "text_excerpt" => entry["text_excerpt"],
                "comment" => entry["comment"],
                "page_path" => entry["page_path"],
                "captured_at" => entry["captured_at"],
                "ancestry" => entry["ancestry"]
              }
            end
            Tools.text_response({ "count" => pending.size, "annotations" => pending })
          end
        end
      end
    end
  end
end
