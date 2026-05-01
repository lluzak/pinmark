# frozen_string_literal: true

require "mcp"

module DesignAnnotations
  module Mcp
    # Builds an MCP::Server instance with the three annotation tools
    # registered. The server is configured via a Queue instance passed through
    # server_context so tools share a single atomic on-disk queue.
    class Server
      NAME = "design-annotations"
      VERSION = "0.1.0"

      def self.build(queue:)
        ::MCP::Server.new(
          name: NAME,
          version: VERSION,
          tools: [
            Tools::ListPending,
            Tools::ListResolved,
            Tools::MarkAddressed,
            Tools::ClearAddressed
          ],
          server_context: { queue: }
        )
      end
    end
  end
end
