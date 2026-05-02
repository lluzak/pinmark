# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pinmark::Mcp::Queue do
  let(:queue_path) { Rails.root.join("tmp", "pinmark", "queue_spec_#{SecureRandom.hex(4)}.json") }
  let(:queue) { described_class.new(queue_path) }

  after do
    FileUtils.rm_f(queue_path)
  end

  def write_raw(annotations)
    queue_path.dirname.mkpath
    File.write(queue_path, JSON.pretty_generate({ "annotations" => annotations }))
  end

  describe "#default_path" do
    it "returns a path under tmp/pinmark" do
      expect(described_class.default_path.to_s).to end_with("tmp/pinmark/queue.json")
    end
  end

  describe "#pending" do
    it "returns only entries with status == 'pending'" do
      write_raw([
                  { "id" => "a", "status" => "pending" },
                  { "id" => "b", "status" => "addressed" },
                  { "id" => "c", "status" => "pending" }
                ])

      expect(queue.pending.map { |e| e["id"] }).to contain_exactly("a", "c")
    end
  end

  describe "#mark_addressed" do
    it "is a no-op when the id does not exist" do
      write_raw([{ "id" => "a", "status" => "pending" }])

      result = queue.mark_addressed("nope")

      expect(result).to eq(found: false)
      expect(queue.read.fetch("annotations").first).to eq("id" => "a", "status" => "pending")
    end

    it "flips status to addressed and stamps addressed_at" do
      write_raw([{ "id" => "a", "status" => "pending" }])

      result = queue.mark_addressed("a")

      entry = queue.read.fetch("annotations").first
      expect(result).to eq(found: true, already_addressed: false)
      expect(entry["status"]).to eq("addressed")
      expect(entry["addressed_at"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it "is idempotent on already-addressed entries" do
      write_raw([{ "id" => "a", "status" => "addressed", "addressed_at" => "2024-01-01T00:00:00Z" }])

      result = queue.mark_addressed("a")

      expect(result).to eq(found: true, already_addressed: true)
      expect(queue.read.fetch("annotations").first["status"]).to eq("addressed")
    end
  end

  describe "#clear_addressed" do
    it "drops only addressed entries and returns counts" do
      write_raw([
                  { "id" => "a", "status" => "pending" },
                  { "id" => "b", "status" => "addressed" },
                  { "id" => "c", "status" => "addressed" }
                ])

      result = queue.clear_addressed

      expect(result).to eq(removed: 2, remaining: 1)
      expect(queue.read.fetch("annotations").map { |e| e["id"] }).to eq(["a"])
    end
  end

  describe "atomic write" do
    it "leaves a valid JSON document containing both entries after sequential writes" do
      queue.append([{ "id" => "a", "status" => "pending" }])
      queue.append([{ "id" => "b", "status" => "pending" }])

      data = JSON.parse(File.read(queue_path))
      expect(data["annotations"].map { |e| e["id"] }).to eq(%w[a b])
    end

    it "round-trips text_excerpt through write/read" do
      queue.append([{
                     "id" => "a",
                     "status" => "pending",
                     "node_id" => "pm-7",
                     "text_excerpt" => "Sample heading text"
                   }])

      entry = queue.read.fetch("annotations").first
      expect(entry["node_id"]).to eq("pm-7")
      expect(entry["text_excerpt"]).to eq("Sample heading text")
    end
  end
end
