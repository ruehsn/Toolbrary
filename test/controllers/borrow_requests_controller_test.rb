require "test_helper"

class BorrowRequestsControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can request a tool" do
    sign_in_as users(:two)
    assert_difference("BorrowRequest.count") do
      post tool_borrow_requests_path(tools(:ladder)),
           params: { borrow_request: { start_date: Date.current, due_date: Date.current + 2, message: "pls" } }
    end
    assert_redirected_to dashboard_path
  end

  test "owner approves and marks returned" do
    sign_in_as users(:one)
    r = borrow_requests(:pending_drill)
    patch approve_borrow_request_path(r)
    assert r.reload.approved?
    patch return_borrow_request_path(r)
    assert r.reload.returned?
  end

  test "borrower cannot approve their own request" do
    sign_in_as users(:two)
    patch approve_borrow_request_path(borrow_requests(:pending_drill))
    assert_response :forbidden
    assert borrow_requests(:pending_drill).reload.pending?
  end

  test "borrower can cancel" do
    sign_in_as users(:two)
    patch cancel_borrow_request_path(borrow_requests(:pending_drill))
    assert borrow_requests(:pending_drill).reload.cancelled?
  end
end
