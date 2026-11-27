require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  test "create shows the token once, stores only a digest, and revoke works" do
    sign_in_as users(:one)
    assert_difference("ApiToken.count") { post api_tokens_path, params: { api_token: { name: "Laptop" } } }
    assert_response :success
    plain = css_select("pre.token code").text.strip
    assert plain.start_with?("tbk_")
    token = ApiToken.last
    assert_not_equal plain, token.token_digest
    assert_equal token, ApiToken.authenticate(plain)
    assert_select "pre", text: /claude mcp add/

    get account_path
    assert_select "code", text: "tbk_…#{plain.last(4)}"
    assert_no_match plain, response.body

    delete api_token_path(token)
    assert_nil ApiToken.authenticate(plain)
  end

  test "cannot revoke someone else's token" do
    token = users(:two).api_tokens.create!(name: "x")
    sign_in_as users(:one)
    delete api_token_path(token)
    assert_response :not_found
  end
end
