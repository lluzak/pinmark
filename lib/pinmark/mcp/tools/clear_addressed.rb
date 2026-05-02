# frozen_string_literal: true

require "mcp"

module Pinmark
  module Mcp
    module Tools
      class ClearAddressed < ::MCP::Tool
        tool_name "clear_addressed"
        description "Drop every entry whose status='addressed' from the queue file. Returns the " \
                    "number removed."
        input_schema(properties: {})

        class << self
          def call(server_context:)
            queue = server_context.fetch(:queue)
            result = queue.clear_addressed
            Tools.text_response({
                                  "ok" => true,
                                  "removed" => result[:removed],
                                  "remaining" => result[:remaining]
                                })
          end
        end
      end
    end
  end
end
