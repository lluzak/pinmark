# frozen_string_literal: true

require "json"
require "securerandom"

module DesignAnnotations
  class AnnotationsController < ApplicationController
    def index
      queue = DesignAnnotations::Mcp::Queue.new
      render json: { annotations: queue.read.fetch("annotations", []) }
    end

    def create
      payload = JSON.parse(request.body.read)
      comments = Array(payload["comments"])
      path = payload["path"]
      tree = payload["tree"]
      replace_match = payload["replace_match"] == true

      queue = DesignAnnotations::Mcp::Queue.new
      data = queue.read
      existing = data.fetch("annotations", [])

      tree_lookup = flatten_tree(tree).index_by { |n| n["id"] }

      new_entries = comments.map do |c|
        annotation_id = c["node_id"] || c["da_id"]
        node = tree_lookup[annotation_id]
        {
          "id" => SecureRandom.uuid,
          "status" => "pending",
          "received_at" => Time.current.iso8601,
          "page_path" => path,
          "component" => c["component"] || node&.dig("component"),
          "source" => c["source"] || node&.dig("source"),
          "node_id" => annotation_id,
          "selector" => c["selector"],
          "text_excerpt" => c["text_excerpt"],
          "comment" => c["comment"],
          "captured_at" => c["captured_at"],
          "ancestry" => component_ancestry(annotation_id, tree_lookup)
        }
      end

      remaining = if replace_match
                    drop_matching(existing, new_entries, path)
                  else
                    existing
                  end

      queue.write({ "annotations" => remaining + new_entries })

      render json: {
        ok: true,
        count: new_entries.size,
        queue: queue.path.relative_path_from(Rails.root).to_s
      }
    end

    def destroy
      queue = DesignAnnotations::Mcp::Queue.new
      data = queue.read
      before = data.fetch("annotations", []).size
      data["annotations"] = data.fetch("annotations", []).reject { |entry| entry["id"] == params[:id] }
      removed = before - data["annotations"].size
      queue.write(data)

      render json: { ok: true, removed: }
    end

    private

    def flatten_tree(nodes, acc = [])
      Array(nodes).each do |node|
        acc << node
        flatten_tree(node["children"], acc)
      end
      acc
    end

    def component_ancestry(annotation_id, lookup)
      chain = []
      current = lookup[annotation_id]
      while current
        chain.unshift(
          "id" => current["id"],
          "component" => current["component"],
          "source" => current["source"]
        )
        current = current["parent_id"] ? lookup[current["parent_id"]] : nil
      end
      chain
    end

    def drop_matching(existing, new_entries, path)
      keys = new_entries.to_set { |e| [e["node_id"], e["selector"], path] }
      existing.reject do |entry|
        keys.include?([entry["node_id"], entry["selector"], entry["page_path"]])
      end
    end
  end
end
