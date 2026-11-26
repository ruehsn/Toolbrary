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
end
