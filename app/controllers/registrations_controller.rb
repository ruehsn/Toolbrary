class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Too many attempts. Try again in a few minutes." }

  def new
    @user = User.new
  end

  # The account is only created once the emailed link is clicked, which proves
  # the person owns the address. If it already has an account we send a normal
  # sign-in link instead (and show the same page, to avoid leaking who's registered).
  def create
    @user = User.new(params.expect(user: %i[name email_address]))
    if (existing = User.find_by(email_address: @user.email_address))
      AuthMailer.magic_link(existing).deliver_later
    elsif @user.valid?
      AuthMailer.signup(@user.name, @user.email_address).deliver_later
    else
      return render(:new, status: :unprocessable_entity)
    end
    redirect_to check_email_session_path, flash: { email: @user.email_address }
  end
end
