# frozen_string_literal: true

require "mcp"

module DesignAnnotations
  module Mcp
    module Tools
      class MarkAddressed < ::MCP::Tool
        tool_name "mark_addressed"
        description "Mark a single annotation as addressed by id. Idempotent: calling on an " \
                    "already-addressed id is a no-op."
        input_schema(
          properties: {
            id: {
              type: "string",
              description: "Annotation id returned by list_pending_annotations"
            }
          },
          required: ["id"]
        )

        class << self
          def call(id:, server_context:)
            queue = server_context.fetch(:queue)
            result = queue.mark_addressed(id)

            unless result[:found]
              return Tools.text_response({ "ok" => false, "error" => "No annotation with id=#{id}" })
            end

            Tools.text_response({
                                  "ok" => true,
                                  "id" => id,
                                  "already_addressed" => result[:already_addressed]
                                })
          end
        end
      end
    end
  end
end
