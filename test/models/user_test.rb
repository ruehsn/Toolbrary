require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    assert_equal "downcased@example.com", User.new(email_address: " DOWNCASED@EXAMPLE.COM ").email_address
  end

  test "requires name and valid email" do
    assert_not User.new(email_address: "x@example.com").valid?
    assert_not User.new(name: "X", email_address: "nope").valid?
  end

  test "gets a webauthn handle on create" do
    user = User.create!(name: "New", email_address: "new@example.com")
    assert user.webauthn_id.present?
  end

  test "magic link token is single use" do
    user = users(:one)
    token = user.generate_token_for(:magic_link)
    assert_equal user, User.find_by_token_for(:magic_link, token)
    user.record_sign_in!
    assert_nil User.find_by_token_for(:magic_link, token)
  end

  test "magic link token expires" do
    token = users(:one).generate_token_for(:magic_link)
    travel 16.minutes
    assert_nil User.find_by_token_for(:magic_link, token)
  end
end
