class DashboardController < ApplicationController
  def show
    user = Current.user
    @tools = user.tools.includes(borrow_requests: :borrower).order(:name)
    @incoming = user.incoming_requests.pending.includes(:tool, :borrower).recent_first
    @lent_out = user.incoming_requests.approved.includes(:tool, :borrower).order(:due_date)
    @my_requests = user.borrow_requests.includes(tool: :user).recent_first.limit(20)
  end
end
