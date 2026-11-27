require "test_helper"

# Exercises the MCP server over HTTP exactly as an assistant would.
class McpEndpointTest < ActionDispatch::IntegrationTest
  setup do
    @token = users(:one).api_tokens.create!(name: "test").plain_token
    @id = 0
  end

  def rpc(method, params = nil, token: @token)
    headers = { "Accept" => "application/json, text/event-stream", "MCP-Protocol-Version" => "2025-06-18" }
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: { jsonrpc: "2.0", id: (@id += 1), method: method, params: params }.compact.to_json,
                 headers: headers.merge("Content-Type" => "application/json")
    response.parsed_body
  end

  def call_tool(name, args = {})
    result = rpc("tools/call", { name: name, arguments: args })
    assert result["result"], "expected a result, got #{result}"
    result["result"]
  end

  test "rejects missing and revoked tokens" do
    rpc("tools/list", token: nil)
    assert_response :unauthorized
    rpc("tools/list", token: "tbk_nope")
    assert_response :unauthorized
    ApiToken.destroy_all
    rpc("tools/list")
    assert_response :unauthorized
  end

  test "initialize and list tools" do
    init = rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" } })
    assert_equal "toolbrary", init.dig("result", "serverInfo", "name")
    assert_match(/photo/, init.dig("result", "instructions"))
    names = rpc("tools/list").dig("result", "tools").map { _1["name"] }
    assert_includes names, "submit_import_items"
    assert_equal 13, names.size
  end

  test "search and my_shed" do
    found = call_tool("search_tools", { query: "drill" })["structuredContent"]["tools"]
    assert_equal [ "Cordless drill" ], found.map { _1["name"] }
    shed = call_tool("my_shed")["structuredContent"]
    assert_equal [ "Weekend project" ], shed["requests_waiting_for_me"].map { _1["message"] }
    assert_equal 2, shed["my_tools"].size
  end

  test "add, update, check out and check in" do
    added = call_tool("add_tool", { name: "Wheelbarrow", category: "Garden & yard", condition: "Fair" })
    assert_not added["isError"]
    tool = Tool.find_by!(name: "Wheelbarrow")
    assert_equal "Garden & yard", tool.category.name

    call_tool("update_tool", { tool_id: tool.id, description: "Pneumatic tyre" })
    assert_equal "Pneumatic tyre", tool.reload.description

    out = call_tool("check_out_tool", { tool_id: tool.id, borrower_name: "Sam", due_date: (Date.current + 3).iso8601 })
    assert_equal "Sam", out["structuredContent"]["borrower"]
    assert_not tool.reload.available?

    call_tool("check_in_tool", { tool_id: tool.id })
    assert tool.reload.available?
  end

  test "bad input comes back as a tool error, not a crash" do
    result = call_tool("check_out_tool", { tool_id: tools(:ladder).id, borrower_name: "Sam", due_date: "next tuesday" })
    assert result["isError"]
    assert_match(/YYYY|2026-12-31/, result["content"][0]["text"])
  end

  test "arguments are validated against the schema" do
    result = call_tool("check_out_tool", { tool_id: tools(:ladder).id, borrower_name: "Sam" })
    assert result["isError"]
    assert_match(/due_date/, result["content"][0]["text"])
  end

  test "cannot touch someone else's tool" do
    other = users(:two).tools.create!(name: "Not yours")
    result = call_tool("update_tool", { tool_id: other.id, name: "Mine now" })
    assert result["isError"]
    assert_equal "Not yours", other.reload.name
    assert call_tool("check_in_tool", { tool_id: other.id })["isError"]
  end

  test "approve a borrow request" do
    call_tool("respond_to_borrow_request", { request_id: borrow_requests(:pending_drill).id, decision: "approve" })
    assert borrow_requests(:pending_drill).reload.approved?
  end

  test "request to borrow as the other user" do
    token = users(:two).api_tokens.create!(name: "t").plain_token
    @token = token
    assert_difference("BorrowRequest.count") do
      call_tool("request_to_borrow", { tool_id: tools(:ladder).id, start_date: Date.current.iso8601,
                                      due_date: (Date.current + 1).iso8601, message: "Gutters" })
    end
  end

  test "photo import handled by the user's own assistant" do
    import = users(:one).tool_imports.new(status: "awaiting_assistant")
    import.photos.attach(io: file_fixture("bench.jpg").open, filename: "bench.jpg", content_type: "image/jpeg")
    import.save!

    waiting = call_tool("list_photo_imports")["structuredContent"]["imports"]
    assert_equal [ import.id ], waiting.map { _1["import_id"] }

    photo = call_tool("get_import_photo", { import_id: import.id, photo_index: 0 })
    image = photo["content"].find { _1["type"] == "image" }
    assert_equal "image/jpeg", image["mimeType"]
    assert Base64.decode64(image["data"]).start_with?("\xFF\xD8".b)
    assert call_tool("get_import_photo", { import_id: import.id, photo_index: 5 })["isError"]

    submitted = call_tool("submit_import_items", { import_id: import.id, items: [
      { photo_index: 0, name: "Red toolbox", category: "Power tools", condition: "Good", description: "Red.", box: [ 100, 200, 400, 800 ] },
      { photo_index: 9, name: "Out of range photo", box: [ 0, 0, 10, 10 ] }
    ] })
    submitted = submitted["structuredContent"]
    assert_equal 1, submitted["items_received"]
    assert_match %r{/tool_imports/#{import.id}\z}, submitted["review_url"]
    import.reload
    assert import.ready?
    assert_equal "Good", import.items.first["condition"]
    assert_equal [ 100, 200, 400, 800 ], import.items.first["box"]
  end

  test "another user's import is invisible" do
    import = users(:two).tool_imports.new(status: "awaiting_assistant")
    import.photos.attach(io: file_fixture("bench.jpg").open, filename: "bench.jpg", content_type: "image/jpeg")
    import.save!
    assert call_tool("get_import_photo", { import_id: import.id, photo_index: 0 })["isError"]
    assert call_tool("submit_import_items", { import_id: import.id, items: [] })["isError"]
  end
end
