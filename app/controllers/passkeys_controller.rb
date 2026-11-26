# Register / rename / remove passkeys for the signed-in user (WebAuthn "create").
class PasskeysController < ApplicationController
  def options
    user = Current.user
    options = WebAuthn::Credential.options_for_create(
      user: { id: user.webauthn_id, name: user.email_address, display_name: user.name },
      exclude: user.passkeys.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "required" }
    )
    session[:passkey_create_challenge] = options.challenge
    render json: options
  end

  def create
    credential = WebAuthn::Credential.from_create(params.require(:credential).to_unsafe_h)
    credential.verify(session.delete(:passkey_create_challenge), user_verification: true)

    Current.user.passkeys.create!(
      external_id: credential.id,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      nickname: params[:nickname].to_s.strip.first(60).presence
    )
    flash[:notice] = "Passkey added. You can now sign in with it."
    render json: { redirect_to: account_path }
  rescue WebAuthn::Error, ActiveRecord::RecordInvalid => e
    Rails.logger.info("Passkey registration failed: #{e.class}: #{e.message}")
    render json: { error: "Couldn't save that passkey. Please try again." }, status: :unprocessable_entity
  end

  def update
    Current.user.passkeys.find(params[:id]).update!(nickname: params.dig(:passkey, :nickname).to_s.strip.first(60))
    redirect_to account_path, notice: "Passkey renamed."
  end

  def destroy
    Current.user.passkeys.find(params[:id]).destroy
    redirect_to account_path, notice: "Passkey removed.", status: :see_other
  end
end
