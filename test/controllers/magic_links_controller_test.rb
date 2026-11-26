require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "GET shows a confirm button and does not sign in" do
    token = users(:one).generate_token_for(:magic_link)
    get magic_link_path(token: token)
    assert_response :success
    assert_select "button", "Sign me in"
    assert_nil cookies[:session_id].presence
  end

  test "POST signs in and the link cannot be reused" do
    token = users(:one).generate_token_for(:magic_link)
    post magic_link_path, params: { token: token }
    assert_redirected_to root_url
    assert cookies[:session_id].present?

    delete session_path
    post magic_link_path, params: { token: token }
    assert_redirected_to new_session_path
  end

  test "bad token" do
    post magic_link_path, params: { token: "garbage" }
    assert_redirected_to new_session_path
    get magic_link_path(token: "garbage")
    assert_select "h1", "Link expired"
  end

  test "signup token creates the account once" do
    token = SignupToken.generate(name: "Casey", email: "casey@example.com")
    assert_difference("User.count") { post magic_link_path, params: { token: token } }
    assert_redirected_to account_path
    assert_no_difference("User.count") { post magic_link_path, params: { token: token } }
    get magic_link_path(token: token)
    assert_select "h1", "Link expired"
  end

  test "expired signup token" do
    token = SignupToken.generate(name: "Casey", email: "casey@example.com")
    travel 61.minutes
    assert_no_difference("User.count") { post magic_link_path, params: { token: token } }
  end
end
