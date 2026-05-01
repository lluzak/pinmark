# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DesignAnnotations::Annotations", type: :request do
  let(:queue_path) { Rails.root.join("tmp/design_annotations/queue.json") }

  let(:tree) do
    [
      {
        "id" => "da-1",
        "component" => "Storefront::Home::HeroComponent",
        "source" => "app/views/storefront/home/hero_component.rb:12",
        "parent_id" => nil,
        "children" => []
      }
    ]
  end

  let(:payload) do
    {
      path: "/",
      capturedAt: "2026-04-30T10:00:00Z",
      tree:,
      comments: [
        {
          node_id: "da-1",
          selector: nil,
          comment: "Hero looks misaligned on mobile",
          component: "Storefront::Home::HeroComponent",
          source: "app/views/storefront/home/hero_component.rb:12",
          text_excerpt: "Welcome to our store",
          captured_at: "2026-04-30T10:00:00Z"
        }
      ]
    }
  end

  before do
    host! "teststore.example.com"
    FileUtils.rm_rf(queue_path.dirname)
  end

  after do
    FileUtils.rm_rf(queue_path.dirname)
  end

  context "POST /dev/design_annotations in development with valid payload" do
    before do
      allow(Rails.env).to receive(:development?).and_return(true)

      post "/dev/design_annotations/annotations",
           params: payload.to_json,
           headers: { "Content-Type" => "application/json" }
    end

    it "responds with HTTP 200" do
      expect(response).to have_http_status(:ok)
    end

    it "reports the count of saved annotations in the response body" do
      expect(response.parsed_body).to include("ok" => true, "count" => 1)
    end

    it "creates the queue file" do
      expect(queue_path).to exist
    end

    it "stores one pending annotation in the queue file" do
      stored = JSON.parse(queue_path.read)
      expect(stored["annotations"].size).to eq(1)
    end

    it "stores the user's comment text" do
      stored = JSON.parse(queue_path.read)
      expect(stored["annotations"].first["comment"]).to eq("Hero looks misaligned on mobile")
    end

    it "marks the new entry as pending" do
      stored = JSON.parse(queue_path.read)
      expect(stored["annotations"].first["status"]).to eq("pending")
    end

    it "stamps the entry with an id and received_at" do
      stored = JSON.parse(queue_path.read)
      entry = stored["annotations"].first
      expect(entry["id"]).to be_present
      expect(entry["received_at"]).to be_present
    end

    it "persists the annotation node id under node_id on the stored entry" do
      stored = JSON.parse(queue_path.read)
      entry = stored["annotations"].first
      expect(entry["node_id"]).to eq("da-1")
      expect(entry.keys).not_to include("da_id")
    end

    it "persists text_excerpt on the stored entry" do
      stored = JSON.parse(queue_path.read)
      expect(stored["annotations"].first["text_excerpt"]).to eq("Welcome to our store")
    end
  end

  context "POST when the queue already has entries" do
    before { allow(Rails.env).to receive(:development?).and_return(true) }

    it "appends new entries instead of replacing them" do
      FileUtils.mkdir_p(queue_path.dirname)
      queue_path.write(JSON.pretty_generate(
                         "annotations" => [
                           { "id" => "existing-1", "status" => "pending", "comment" => "old" }
                         ]
                       ))

      post "/dev/design_annotations/annotations",
           params: payload.to_json,
           headers: { "Content-Type" => "application/json" }

      stored = JSON.parse(queue_path.read)
      expect(stored["annotations"].pluck("comment")).to eq(["old", "Hero looks misaligned on mobile"])
    end

    it "replaces an existing matching entry when replace_match is true" do
      FileUtils.mkdir_p(queue_path.dirname)
      queue_path.write(JSON.pretty_generate(
                         "annotations" => [
                           {
                             "id" => "existing-1",
                             "status" => "pending",
                             "comment" => "old comment",
                             "page_path" => "/",
                             "selector" => nil,
                             "node_id" => "da-1"
                           }
                         ]
                       ))

      replace_payload = payload.merge(
        replace_match: true,
        comments: [payload[:comments].first.merge(comment: "updated comment")]
      )

      post "/dev/design_annotations/annotations",
           params: replace_payload.to_json,
           headers: { "Content-Type" => "application/json" }

      stored = JSON.parse(queue_path.read)
      expect(stored["annotations"].pluck("comment")).to eq(["updated comment"])
    end
  end

  context "GET /dev/design_annotations in development" do
    before { allow(Rails.env).to receive(:development?).and_return(true) }

    it "returns all annotations from the queue" do
      FileUtils.mkdir_p(queue_path.dirname)
      queue_path.write(JSON.pretty_generate(
                         "annotations" => [
                           { "id" => "x1", "status" => "pending", "comment" => "first" },
                           { "id" => "x2", "status" => "addressed", "comment" => "second" }
                         ]
                       ))

      get "/dev/design_annotations/annotations"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["annotations"].pluck("id")).to eq(%w[x1 x2])
    end

    it "returns an empty list when the queue file does not exist" do
      get "/dev/design_annotations/annotations"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["annotations"]).to eq([])
    end
  end

  context "DELETE /dev/design_annotations/:id in development" do
    before { allow(Rails.env).to receive(:development?).and_return(true) }

    it "removes the matching entry from the queue" do
      FileUtils.mkdir_p(queue_path.dirname)
      queue_path.write(JSON.pretty_generate(
                         "annotations" => [
                           { "id" => "x1", "status" => "pending", "comment" => "first" },
                           { "id" => "x2", "status" => "pending", "comment" => "second" }
                         ]
                       ))

      delete "/dev/design_annotations/annotations/x1"

      expect(response).to have_http_status(:ok)
      stored = JSON.parse(queue_path.read)
      expect(stored["annotations"].pluck("id")).to eq(["x2"])
    end
  end

  context "outside of development env" do
    before { allow(Rails.env).to receive(:development?).and_return(false) }

    it "returns 404 from the controller's own guard on POST" do
      post "/dev/design_annotations/annotations",
           params: payload.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end

    it "does not create the queue file" do
      post "/dev/design_annotations/annotations",
           params: payload.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(queue_path).not_to exist
    end

    it "returns 404 on GET" do
      get "/dev/design_annotations/annotations"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 on DELETE" do
      delete "/dev/design_annotations/annotations/anything"
      expect(response).to have_http_status(:not_found)
    end
  end
end
