class UsersController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def show
    @user = User.find(params[:id])
    @tools = @user.tools.includes(:user, :category, :borrow_requests, photos_attachments: :blob).order(:name)
  end
end
