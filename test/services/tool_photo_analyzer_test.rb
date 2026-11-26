require "test_helper"

class ToolPhotoAnalyzerTest < ActiveSupport::TestCase
  Block = Struct.new(:type, :text)
  Response = Struct.new(:stop_reason, :content)

  class FakeClient
    attr_reader :calls
    def initialize(response) = (@response = response; @calls = [])
    def beta = self
    def messages = self
    def create(**kwargs) = (@calls << kwargs; @response)
  end

  setup do
    @blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("bench.jpg").open, filename: "bench.jpg", content_type: "image/jpeg")
    ENV["ANTHROPIC_API_KEY"] = "test-key"
  end

  teardown do
    ENV.delete("ANTHROPIC_API_KEY")
    ToolPhotoAnalyzer.client_factory = nil
  end

  def with_response(response)
    client = FakeClient.new(response)
    ToolPhotoAnalyzer.client_factory = -> { client }
    [ client, ToolPhotoAnalyzer.new(categories: [ "Power tools", "Other" ]) ]
  end

  test "sends a downscaled JPEG with a JSON schema and parses the tools" do
    json = { tools: [ { name: "Drill", category: "Power tools", condition: "Good", description: "Cordless.", box: [ 100, 200, 400, 800 ] } ] }.to_json
    client, analyzer = with_response(Response.new(:end_turn, [ Block.new(:text, json) ]))

    items = analyzer.analyze(@blob)

    assert_equal "Drill", items.first["name"]
    assert_equal [ 100, 200, 400, 800 ], items.first["box"]
    call = client.calls.first
    assert_equal :"claude-opus-5-5", call[:model]
    assert_equal :json_schema, call.dig(:output_config, :format, :type)
    assert_equal :default, call[:fallbacks]
    image = call[:messages].first[:content].first
    assert_equal "image/jpeg", image.dig(:source, :media_type)
    assert Base64.strict_decode64(image.dig(:source, :data)).start_with?("\xFF\xD8".b)
    assert_includes call[:system_], "Power tools, Other"
  end

  test "refusal becomes a friendly error" do
    _, analyzer = with_response(Response.new(:refusal, []))
    assert_raises(ToolPhotoAnalyzer::Error) { analyzer.analyze(@blob) }
  end

  test "garbage output becomes a friendly error" do
    _, analyzer = with_response(Response.new(:end_turn, [ Block.new(:text, "not json") ]))
    assert_raises(ToolPhotoAnalyzer::Error) { analyzer.analyze(@blob) }
  end

  test "not configured without an API key" do
    ENV.delete("ANTHROPIC_API_KEY")
    assert_raises(ToolPhotoAnalyzer::NotConfigured) { ToolPhotoAnalyzer.new(categories: []).analyze(@blob) }
  end
end
