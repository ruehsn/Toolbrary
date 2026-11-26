require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "owner sees incoming requests" do
    sign_in_as users(:one)
    get dashboard_path
    assert_response :success
    assert_select "td", text: /Weekend project/
  end
end
