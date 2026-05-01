# frozen_string_literal: true

require "json"
require "mcp"

module DesignAnnotations
  module Mcp
    module Tools
      class ListResolved < ::MCP::Tool
        tool_name "list_resolved_annotations"
        description "Return every annotation in the queue with status='addressed'. Use this " \
                    "to audit annotations that have already been handled, e.g. for a " \
                    "post-pass review or to undo. Same shape as list_pending_annotations, " \
                    "plus addressed_at."
        input_schema(properties: {})

        class << self
          def call(server_context:)
            queue = server_context.fetch(:queue)
            resolved = queue.addressed.map do |entry|
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
                "addressed_at" => entry["addressed_at"],
                "ancestry" => entry["ancestry"]
              }
            end
            Tools.text_response({ "count" => resolved.size, "annotations" => resolved })
          end
        end
      end
    end
  end
end
