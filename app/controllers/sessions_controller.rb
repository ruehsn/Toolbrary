class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create check_email]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again in a few minutes." }

  def new
  end

  # Emails a magic sign-in link. The response is identical whether or not the
  # address has an account, so this can't be used to discover who is registered.
  def create
    email = params[:email_address].to_s.strip.downcase
    if (user = User.find_by(email_address: email))
      AuthMailer.magic_link(user).deliver_later
    end
    redirect_to check_email_session_path, flash: { email: email }
  end

  def check_email
    @email = flash[:email]
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other
  end
end
