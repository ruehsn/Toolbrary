# Sign in with a passkey (WebAuthn "get"). Uses discoverable credentials, so
# the user doesn't type an email: the browser offers the passkeys it has for this site.
class PasskeySessionsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 20, within: 3.minutes, only: :create, with: -> { render json: { error: "Too many attempts" }, status: :too_many_requests }

  def options
    options = WebAuthn::Credential.options_for_get(user_verification: "required")
    session[:passkey_auth_challenge] = options.challenge
    render json: options
  end

  def create
    credential = WebAuthn::Credential.from_get(params.require(:credential).to_unsafe_h)
    passkey = Passkey.find_by(external_id: credential.id)
    return render(json: { error: "This passkey isn't registered with Tool Share." }, status: :unprocessable_entity) unless passkey

    credential.verify(
      session.delete(:passkey_auth_challenge),
      public_key: passkey.public_key,
      sign_count: passkey.sign_count,
      user_verification: true
    )
    if credential.user_handle.present? && credential.user_handle != passkey.user.webauthn_id
      raise WebAuthn::Error, "user handle mismatch"
    end

    passkey.update!(sign_count: credential.sign_count, last_used_at: Time.current)
    start_new_session_for passkey.user
    flash[:notice] = "Signed in with your passkey."
    render json: { redirect_to: after_authentication_url }
  rescue WebAuthn::Error => e
    Rails.logger.info("Passkey sign-in failed: #{e.class}: #{e.message}")
    render json: { error: "Couldn't verify that passkey. Try again or use an email link." }, status: :unprocessable_entity
  end
end
