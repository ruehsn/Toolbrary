require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "sign up creates user and signs in" do
    assert_difference("User.count") do
      post registration_path, params: { user: { name: "New", email_address: "new@example.com", password: "password123", password_confirmation: "password123" } }
    end
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
  end

  test "invalid sign up re-renders" do
    post registration_path, params: { user: { name: "", email_address: "bad", password: "x", password_confirmation: "y" } }
    assert_response :unprocessable_entity
  end
end
