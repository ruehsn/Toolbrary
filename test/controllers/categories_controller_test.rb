require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "index is public" do
    get categories_path
    assert_response :success
    assert_select ".cat-card", Category.count
  end

  test "signed-in users can add a category" do
    sign_in_as users(:two)
    assert_difference("Category.count") { post categories_path, params: { category: { name: "Bike repair", icon: "🚲" } } }
    post categories_path, params: { category: { name: "bike repair" } }
    assert_response :unprocessable_entity
  end

  test "signed-out users cannot add" do
    post categories_path, params: { category: { name: "X" } }
    assert_redirected_to new_session_path
  end
end
