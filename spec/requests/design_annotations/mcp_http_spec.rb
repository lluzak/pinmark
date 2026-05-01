# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dev design annotations endpoint", type: :request do
  let(:queue_path) { Rails.root.join("tmp/design_annotations/queue.json") }

  before do
    FileUtils.mkdir_p(queue_path.dirname)
    File.write(queue_path, JSON.pretty_generate({ "annotations" => [] }))
    host! "multistore.localhost"
  end

  after do
    FileUtils.rm_f(queue_path)
  end

  def jsonrpc(method, params: nil, id: 1, session_id: nil)
    body = { jsonrpc: "2.0", id:, method: }
    body[:params] = params if params

    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream"
    }
    headers["Mcp-Session-Id"] = session_id if session_id

    post "/dev/design_annotations/annotations/mcp", params: body.to_json, headers:
  end

  def parse_response_body
    body = response.body.to_s
    if body.start_with?("event:") || body.include?("\ndata:") || body.start_with?("data:")
      data_line = body.lines.find { |l| l.start_with?("data:") }
      JSON.parse(data_line.sub(/\Adata:\s*/, "").strip)
    else
      JSON.parse(body)
    end
  end

  def initialize_session
    jsonrpc("initialize", params: {
              protocolVersion: "2025-03-26",
              capabilities: {},
              clientInfo: { name: "rspec", version: "0" }
            })
    response.headers["Mcp-Session-Id"] || response.headers["mcp-session-id"]
  end

  it "lists the three annotation tools" do
    session_id = initialize_session
    expect(response).to have_http_status(:ok)

    jsonrpc("tools/list", id: 2, session_id:)

    payload = parse_response_body
    tool_names = payload.dig("result", "tools").map { |t| t["name"] }
    expect(tool_names).to contain_exactly(
      "list_pending_annotations",
      "list_resolved_annotations",
      "mark_addressed",
      "clear_addressed"
    )
  end

  it "returns seeded pending entries via list_pending_annotations" do
    File.write(queue_path, JSON.pretty_generate({
                                                  "annotations" => [
                                                    {
                                                      "id" => "seed-1",
                                                      "status" => "pending",
                                                      "component" => "FooComponent",
                                                      "comment" => "needs spacing"
                                                    },
                                                    {
                                                      "id" => "seed-2",
                                                      "status" => "addressed"
                                                    }
                                                  ]
                                                }))

    session_id = initialize_session
    jsonrpc("tools/call", id: 3, session_id:, params: {
              name: "list_pending_annotations",
              arguments: {}
            })

    payload = parse_response_body
    text = payload.dig("result", "content", 0, "text")
    parsed = JSON.parse(text)

    expect(parsed["count"]).to eq(1)
    expect(parsed["annotations"].first["id"]).to eq("seed-1")
  end

  it "exposes node_id and text_excerpt in list_pending_annotations output" do
    File.write(queue_path, JSON.pretty_generate({
                                                  "annotations" => [
                                                    {
                                                      "id" => "seed-1",
                                                      "status" => "pending",
                                                      "node_id" => "da-42",
                                                      "component" => "FooComponent",
                                                      "comment" => "needs spacing",
                                                      "text_excerpt" => "Hello world"
                                                    }
                                                  ]
                                                }))

    session_id = initialize_session
    jsonrpc("tools/call", id: 3, session_id:, params: {
              name: "list_pending_annotations",
              arguments: {}
            })

    parsed = JSON.parse(parse_response_body.dig("result", "content", 0, "text"))
    entry = parsed["annotations"].first
    expect(entry["node_id"]).to eq("da-42")
    expect(entry["text_excerpt"]).to eq("Hello world")
  end
end
