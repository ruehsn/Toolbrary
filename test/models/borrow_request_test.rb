require "test_helper"

class BorrowRequestTest < ActiveSupport::TestCase
  test "cannot borrow your own tool" do
    r = tools(:drill).borrow_requests.new(borrower: users(:one), start_date: Date.current, due_date: Date.current)
    assert_not r.valid?
    assert_includes r.errors[:base], "You can't borrow your own tool"
  end

  test "due date must not be before start date" do
    r = tools(:drill).borrow_requests.new(borrower: users(:two), start_date: Date.current, due_date: Date.current - 1)
    assert_not r.valid?
  end

  test "approving marks tool unavailable and returning frees it" do
    r = borrow_requests(:pending_drill)
    assert tools(:drill).available?
    r.approve!
    assert_not tools(:drill).reload.available?
    assert_not_includes Tool.available, tools(:drill)
    r.mark_returned!
    assert tools(:drill).reload.available?
    assert r.returned_at.present?
  end

  test "cannot approve a second loan while tool is out" do
    borrow_requests(:pending_drill).approve!
    other = User.create!(name: "Three", email_address: "three@example.com", webauthn_id: "three")
    second = tools(:drill).borrow_requests.create!(borrower: other, start_date: Date.current, due_date: Date.current + 1)
    assert_raises(ActiveRecord::RecordInvalid) { second.approve! }
  end

  test "overdue when approved and past due" do
    r = borrow_requests(:pending_drill)
    r.update!(status: "approved", start_date: Date.current - 5, due_date: Date.current - 1)
    assert r.overdue?
  end
end

class OfflineLoanTest < ActiveSupport::TestCase
  test "owner can check out to a named non-member" do
    loan = tools(:ladder).borrow_requests.create!(status: "approved", borrower_name: "Grandpa Joe",
                                                 start_date: Date.current, due_date: Date.current + 3)
    assert_equal "Grandpa Joe", loan.borrower_display_name
    assert loan.checked_out_at.present?
    assert_not tools(:ladder).reload.available?
  end

  test "needs either a member or a name" do
    loan = tools(:ladder).borrow_requests.new(status: "approved", start_date: Date.current, due_date: Date.current)
    assert_not loan.valid?
  end
end
