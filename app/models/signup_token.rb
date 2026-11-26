# Signed, expiring token carrying a pending sign-up (name + email).
# Nothing is stored until the link is clicked.
module SignupToken
  PURPOSE = :signup
  EXPIRES_IN = 1.hour

  def self.generate(name:, email:)
    verifier.generate({ "name" => name, "email" => email }, purpose: PURPOSE, expires_in: EXPIRES_IN)
  end

  def self.read(token)
    data = verifier.verified(token, purpose: PURPOSE)
    data && { name: data["name"], email: data["email"] }
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
    nil
  end

  def self.verifier = Rails.application.message_verifier(:signup)
end
