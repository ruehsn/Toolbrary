require "test_helper"
require "webauthn/fake_client"

# Full WebAuthn round trips using the webauthn gem's software authenticator.
class PasskeysFlowTest < ActionDispatch::IntegrationTest
  setup { @client = WebAuthn::FakeClient.new("http://www.example.com") }

  def register_passkey(nickname: "Laptop")
    post options_passkeys_path, as: :json
    options = response.parsed_body
    assert_equal users(:one).webauthn_id, options["user"]["id"]
    credential = @client.create(challenge: options["challenge"], user_verified: true)
    post passkeys_path, params: { credential: credential, nickname: nickname }, as: :json
  end

  test "register a passkey then sign in with it" do
    sign_in_as users(:one)
    assert_difference("Passkey.count") { register_passkey }
    assert_response :success
    assert_equal "Laptop", users(:one).passkeys.last.nickname

    delete session_path
    post options_passkey_session_path, as: :json
    challenge = response.parsed_body["challenge"]
    assertion = @client.get(challenge: challenge, user_verified: true)
    post passkey_session_path, params: { credential: assertion }, as: :json

    assert_response :success
    assert_equal root_url, response.parsed_body["redirect_to"]
    assert users(:one).passkeys.last.last_used_at.present?
    get dashboard_path
    assert_response :success
  end

  test "registration requires sign in" do
    post options_passkeys_path, as: :json
    assert_redirected_to new_session_path
  end

  test "replayed challenge is rejected" do
    sign_in_as users(:one)
    register_passkey
    delete session_path

    post options_passkey_session_path, as: :json
    assertion = @client.get(challenge: response.parsed_body["challenge"], user_verified: true)
    post passkey_session_path, params: { credential: assertion }, as: :json
    assert_response :success
    delete session_path

    # Same assertion again: the challenge was consumed from the session.
    post passkey_session_path, params: { credential: assertion }, as: :json
    assert_response :unprocessable_entity
  end

  test "unknown passkey is rejected" do
    other = WebAuthn::FakeClient.new("http://www.example.com")
    post options_passkey_session_path, as: :json
    other.create(challenge: response.parsed_body["challenge"]) # never registered with the app
    assertion = other.get(challenge: response.parsed_body["challenge"], user_verified: true)
    post passkey_session_path, params: { credential: assertion }, as: :json
    assert_response :unprocessable_entity
  end

  test "user can remove only their own passkey" do
    sign_in_as users(:one)
    register_passkey
    passkey = Passkey.last
    sign_in_as users(:two)
    delete passkey_path(passkey)
    assert_response :not_found
    sign_in_as users(:one)
    assert_difference("Passkey.count", -1) { delete passkey_path(passkey) }
  end
end
