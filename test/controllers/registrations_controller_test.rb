require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "sign up emails a confirmation link without creating the user yet" do
    assert_no_difference("User.count") do
      assert_enqueued_email_with AuthMailer, :signup, args: [ "New", "new@example.com" ] do
        post registration_path, params: { user: { name: "New", email_address: "New@example.com" } }
      end
    end
    assert_redirected_to check_email_session_path
    follow_redirect!
    assert_select "h1", /Check your email/
  end

  test "existing email gets a sign-in link instead" do
    assert_enqueued_email_with AuthMailer, :magic_link, args: [ users(:one) ] do
      post registration_path, params: { user: { name: "Someone", email_address: "one@example.com" } }
    end
  end

  test "invalid sign up re-renders" do
    post registration_path, params: { user: { name: "", email_address: "bad" } }
    assert_response :unprocessable_entity
  end
end
