class AuthMailer < ApplicationMailer
  def magic_link(user)
    @user = user
    @url = magic_link_url(token: user.generate_token_for(:magic_link))
    mail to: user.email_address, subject: "Your Toolbrary sign-in link"
  end

  def signup(name, email)
    @name = name
    @url = magic_link_url(token: SignupToken.generate(name: name, email: email))
    mail to: email, subject: "Confirm your Toolbrary account"
  end
end
