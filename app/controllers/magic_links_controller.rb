class MagicLinksController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 20, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again in a few minutes." }

  # Email scanners often "click" links automatically, so a GET never signs you
  # in; it just shows a button that POSTs the token.
  def show
    @token = params[:token].to_s
    signup = SignupToken.read(@token)
    @valid = User.find_by_token_for(:magic_link, @token).present? ||
             (signup.present? && !User.exists?(email_address: signup[:email]))
  end

  def create
    token = params[:token].to_s
    if (user = User.find_by_token_for(:magic_link, token))
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Signed in. Welcome back, #{user.name}!"
    elsif (signup = SignupToken.read(token)) && !User.exists?(email_address: signup[:email])
      user = User.create!(name: signup[:name], email_address: signup[:email])
      start_new_session_for user
      redirect_to account_path, notice: "Welcome, #{user.name}! Add a passkey so next time you can sign in with one tap."
    else
      redirect_to new_session_path, alert: "That link has expired or was already used. Request a new one below."
    end
  end
end
