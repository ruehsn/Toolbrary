class UsersController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def show
    @user = User.find(params[:id])
    @tools = @user.tools.includes(:borrow_requests).order(:name)
  end
end
