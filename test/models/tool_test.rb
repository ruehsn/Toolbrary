require "test_helper"

class ToolTest < ActiveSupport::TestCase
  test "requires a name" do
    assert_not Tool.new(user: users(:one)).valid?
  end

  test "search matches name and description" do
    assert_includes Tool.search("drill"), tools(:drill)
    assert_includes Tool.search("charger"), tools(:drill)
    assert_not_includes Tool.search("drill"), tools(:ladder)
  end

  test "replacement_url must be http(s)" do
    tool = tools(:drill)
    tool.replacement_url = "javascript:alert(1)"
    assert_not tool.valid?
    tool.replacement_url = "https://shop.example.com/drill"
    assert tool.valid?
  end

  test "new_category_name creates and assigns a category" do
    tool = users(:one).tools.create!(name: "Pump", new_category_name: "Bike repair")
    assert_equal "Bike repair", tool.category.name
  end

  test "rejects non-image uploads" do
    tool = tools(:drill)
    tool.photos.attach(io: file_fixture("notes.txt").open, filename: "notes.txt", content_type: "text/plain")
    assert_not tool.valid?
    assert tool.errors[:photos].any?
  end
end
