class BorrowRequestsController < ApplicationController
  def create
    @tool = Tool.find(params[:tool_id])
    @borrow_request = @tool.borrow_requests.new(request_params.merge(borrower: Current.user))
    if @borrow_request.save
      redirect_to dashboard_path, notice: "Request sent to #{@tool.user.name}."
    else
      redirect_to @tool, alert: @borrow_request.errors.full_messages.to_sentence
    end
  end

  # Owner actions
  def approve = transition(:owner) { |r| r.approve! }
  def decline = transition(:owner) { |r| r.decline! }
  def return  = transition(:owner) { |r| r.mark_returned! }
  # Borrower action
  def cancel  = transition(:borrower) { |r| r.cancel! }

  private
    def request_params
      params.expect(borrow_request: %i[start_date due_date message])
    end

    def transition(role)
      request = BorrowRequest.find(params[:id])
      allowed = role == :owner ? request.owner == Current.user : request.borrower == Current.user
      return head(:forbidden) unless allowed

      yield request
      redirect_back_or_to dashboard_path, notice: "Request #{request.status}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_back_or_to dashboard_path, alert: e.record.errors.full_messages.to_sentence
    end
end
