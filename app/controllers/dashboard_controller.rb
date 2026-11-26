class DashboardController < ApplicationController
  def show
    user = Current.user
    @tools = user.tools.includes(:category, :user, photos_attachments: :blob, borrow_requests: :borrower).order(:name)
    @incoming = user.incoming_requests.pending.includes(:tool, :borrower).recent_first
    @lent_out = user.incoming_requests.approved.includes(:tool, :borrower).order(:due_date)
    @my_requests = user.borrow_requests.includes(tool: :user).recent_first.limit(20)
    @imports = user.tool_imports.where(status: %w[pending processing ready failed]).order(created_at: :desc)
  end
end
