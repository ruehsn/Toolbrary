require "test_helper"

class ToolsControllerTest < ActionDispatch::IntegrationTest
  test "anyone can browse and view tools" do
    get root_path
    assert_response :success
    assert_select "h3", "Cordless drill"
    get tool_path(tools(:drill))
    assert_response :success
  end

  test "available filter hides lent tools" do
    borrow_requests(:pending_drill).approve!
    get root_path, params: { available: "1" }
    assert_select "h3", text: "Cordless drill", count: 0
    assert_select "h3", "Ladder"
  end

  test "must sign in to add a tool" do
    get new_tool_path
    assert_redirected_to new_session_path
  end

  test "owner can create, update and delete" do
    sign_in_as users(:one)
    assert_difference("Tool.count") do
      post tools_path, params: { tool: { name: "Sander", category: "Power tools" } }
    end
    tool = Tool.last
    patch tool_path(tool), params: { tool: { name: "Orbital sander" } }
    assert_equal "Orbital sander", tool.reload.name
    assert_difference("Tool.count", -1) { delete tool_path(tool) }
  end

  test "non-owner cannot edit someone else's tool" do
    sign_in_as users(:two)
    patch tool_path(tools(:drill)), params: { tool: { name: "Hacked" } }
    assert_response :not_found
    assert_equal "Cordless drill", tools(:drill).reload.name
  end
end
