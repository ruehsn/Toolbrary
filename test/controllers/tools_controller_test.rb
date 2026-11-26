require "test_helper"

class ToolsControllerTest < ActionDispatch::IntegrationTest
  test "anyone can browse and view tools" do
    get root_path
    assert_response :success
    assert_select "h3", "Cordless drill"
    get tool_path(tools(:drill))
    assert_response :success
  end

  test "filter by category" do
    get root_path, params: { category: categories(:ladders).to_param }
    assert_select "h3", text: "Cordless drill", count: 0
    assert_select "h3", "Ladder"
  end

  test "available filter hides checked-out tools" do
    borrow_requests(:pending_drill).approve!
    get root_path, params: { available: "1" }
    assert_select "h3", text: "Cordless drill", count: 0
    assert_select "h3", "Ladder"
  end

  test "must sign in to add a tool" do
    get new_tool_path
    assert_redirected_to new_session_path
  end

  test "owner can create with photos and a new category, update and delete" do
    sign_in_as users(:one)
    assert_difference(%w[Tool.count Category.count]) do
      post tools_path, params: { tool: {
        name: "Sander", new_category_name: "Sanding", replacement_url: "https://example.com/sander",
        photos: [ fixture_file_upload("bench.jpg", "image/jpeg") ]
      } }
    end
    tool = Tool.last
    assert_equal 1, tool.photos.count
    follow_redirect!
    assert_select "a", /Buy a replacement/

    # add one photo, remove the original
    patch tool_path(tool), params: { tool: { name: "Orbital sander", remove_photo_ids: [ tool.photos.first.id ],
                                             photos: [ fixture_file_upload("bench.jpg", "image/jpeg") ] } }
    tool.reload
    assert_equal "Orbital sander", tool.name
    assert_equal 1, tool.photos.count
    assert_difference("Tool.count", -1) { delete tool_path(tool) }
  end

  test "invalid photo is rejected and nothing is attached" do
    sign_in_as users(:one)
    patch tool_path(tools(:drill)), params: { tool: { photos: [ fixture_file_upload("notes.txt", "text/plain") ] } }
    assert_response :unprocessable_entity
    assert_equal 0, tools(:drill).reload.photos.count
  end

  test "non-owner cannot edit someone else's tool" do
    sign_in_as users(:two)
    patch tool_path(tools(:drill)), params: { tool: { name: "Hacked" } }
    assert_response :not_found
    assert_equal "Cordless drill", tools(:drill).reload.name
  end

  test "owner checks out to a non-member by name and checks it back in" do
    sign_in_as users(:one)
    post check_out_tool_path(tools(:ladder)), params: { check_out: { borrower_name: "Neighbour Sam", due_date: Date.current + 2 } }
    loan = tools(:ladder).borrow_requests.last
    assert loan.approved?
    assert_equal "Neighbour Sam", loan.borrower_display_name
    follow_redirect!
    assert_select "h3", "Checked out"

    patch return_borrow_request_path(loan)
    assert loan.reload.returned?
    assert tools(:ladder).reload.available?
    get tool_path(tools(:ladder))
    assert_select "h2", "Check-out history"
  end

  test "owner checks out to a member by email" do
    sign_in_as users(:one)
    post check_out_tool_path(tools(:ladder)), params: { check_out: { borrower_email: "TWO@example.com", due_date: Date.current + 2 } }
    assert_equal users(:two), tools(:ladder).borrow_requests.last.borrower
  end

  test "unknown email is rejected" do
    sign_in_as users(:one)
    assert_no_difference("BorrowRequest.count") do
      post check_out_tool_path(tools(:ladder)), params: { check_out: { borrower_email: "nobody@example.com", due_date: Date.current } }
    end
  end

  test "cannot check out a tool that is already out" do
    sign_in_as users(:one)
    borrow_requests(:pending_drill).approve!
    assert_no_difference("BorrowRequest.count") do
      post check_out_tool_path(tools(:drill)), params: { check_out: { borrower_name: "X", due_date: Date.current } }
    end
  end

  test "only the owner can check out" do
    sign_in_as users(:two)
    post check_out_tool_path(tools(:ladder)), params: { check_out: { borrower_name: "X", due_date: Date.current } }
    assert_response :not_found
  end
end
