# frozen_string_literal: true

require "mcp"
require "mcp/server/transports/streamable_http_transport"

module DesignAnnotations
  module Mcp
    # Rack-mountable adapter that exposes the design annotations server
    # over the official `mcp` gem's Streamable HTTP transport. Designed to be
    # mounted inside a Rails router (or any Rack stack), so the standalone
    # Puma process the gem ships is unnecessary.
    #
    # This class deliberately avoids any Rails-app-specific references
    # (controllers, Current attributes, etc.) so the entire DesignAnnotations::Mcp
    # namespace can later be extracted as a Rails engine / standalone gem.
    class RackApp
      # Run the transport in stateless mode: every request stands on its own,
      # no per-session state is held in memory. This makes the mount
      # resilient to Rails' dev-mode code reloading (which can rebuild the
      # mounted Rack instance) and keeps the in-process server cheap to
      # operate. The annotation tools are simple request/response —
      # they do not need streaming notifications.
      def initialize(queue: Queue.new)
        @queue = queue
        @server = Server.build(queue: @queue)
        @transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(
          @server,
          stateless: true,
          enable_json_response: true
        )
      end

      delegate :call, to: :@transport
    end
  end
end
