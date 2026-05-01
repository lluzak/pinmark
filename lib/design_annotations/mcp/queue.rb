# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"

module DesignAnnotations
  module Mcp
    # Persists the design annotation queue file with atomic writes so concurrent
    # readers (the Rails endpoint and the MCP tools) never see a half-written
    # JSON document.
    class Queue
      attr_reader :path

      def self.default_path
        Rails.root.join("tmp/design_annotations/queue.json")
      end

      def initialize(path = nil)
        @path = Pathname.new(path || self.class.default_path).expand_path
        ensure_file
      end

      def ensure_file
        FileUtils.mkdir_p(@path.dirname)
        return if @path.exist?

        write({ "annotations" => [] })
      end

      def read
        ensure_file
        parsed = JSON.parse(@path.read)
        parsed["annotations"] = [] unless parsed["annotations"].is_a?(Array)
        parsed
      rescue JSON::ParserError
        { "annotations" => [] }
      end

      def write(data)
        tmp = Pathname.new("#{@path}.tmp")
        tmp.write(JSON.pretty_generate(data))
        File.rename(tmp, @path)
      end

      def pending
        read.fetch("annotations", []).select { |entry| entry["status"] == "pending" }
      end

      def append(entries)
        data = read
        data["annotations"] = data.fetch("annotations", []) + Array(entries)
        write(data)
        data["annotations"]
      end

      def mark_addressed(id)
        data = read
        found = false
        already_addressed = false

        data["annotations"] = data.fetch("annotations", []).map do |entry|
          next entry unless entry["id"] == id

          found = true
          already_addressed = true if entry["status"] == "addressed"
          entry.merge("status" => "addressed", "addressed_at" => Time.now.utc.iso8601)
        end

        return { found: false } unless found

        write(data)
        { found: true, already_addressed: }
      end

      def clear_addressed
        data = read
        before = data.fetch("annotations", []).size
        data["annotations"] = data.fetch("annotations", []).reject { |entry| entry["status"] == "addressed" }
        removed = before - data["annotations"].size
        write(data)
        { removed:, remaining: data["annotations"].size }
      end
    end
  end
end
