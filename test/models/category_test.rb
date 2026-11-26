require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "find_or_create_by_name is case-insensitive and squishes" do
    assert_equal categories(:power), Category.find_or_create_by_name("  power   TOOLS ")
    assert_difference("Category.count") { Category.find_or_create_by_name("Bike repair") }
    assert_nil Category.find_or_create_by_name(" ")
  end

  test "names are unique ignoring case" do
    assert_not Category.new(name: "power tools").valid?
  end

  test "Other sorts last" do
    assert_equal "Other", Category.alphabetical.last.name
  end
end
