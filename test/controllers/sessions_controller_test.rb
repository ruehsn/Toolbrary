require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "new" do
    get new_session_path
    assert_response :success
    assert_select "button", /passkey/
  end

  test "known email gets a magic link" do
    assert_enqueued_email_with AuthMailer, :magic_link, args: [ users(:one) ] do
      post session_path, params: { email_address: " ONE@example.com " }
    end
    assert_redirected_to check_email_session_path
    follow_redirect!
    assert_select "h1", /Check your email/
  end

  test "unknown email gets the same page but no email" do
    assert_no_enqueued_emails do
      post session_path, params: { email_address: "nobody@example.com" }
    end
    assert_redirected_to check_email_session_path
    follow_redirect!
    assert_select "h1", /Check your email/
  end

  test "destroy" do
    sign_in_as users(:one)
    delete session_path
    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
