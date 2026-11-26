require "test_helper"

class ToolImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # The test image has a red block at x 100-400, y 100-400 and a blue one at x 600-900, y 150-350 (of 1000x500).
  FOUND = [
    { "name" => "Red toolbox", "category" => "Power tools", "condition" => "Good", "description" => "Red.", "box" => [ 100, 200, 400, 800 ] },
    { "name" => "Blue case", "category" => "ladders & ACCESS", "condition" => "Worn", "description" => "Blue.", "box" => [ 600, 300, 900, 700 ] }
  ].freeze

  setup { ToolPhotoAnalyzer.stub = ->(_blob, _categories) { FOUND.map(&:dup) } }
  teardown { ToolPhotoAnalyzer.stub = nil }

  def upload_and_analyze
    perform_enqueued_jobs do
      post tool_imports_path, params: { tool_import: { photos: [ fixture_file_upload("bench.jpg", "image/jpeg") ] } }
    end
    ToolImport.last
  end

  test "requires sign in" do
    get new_tool_import_path
    assert_redirected_to new_session_path
  end

  test "upload, review, then add selected tools with cropped photos" do
    sign_in_as users(:one)
    import = upload_and_analyze
    assert_redirected_to tool_import_path(import)
    assert import.reload.ready?
    assert_equal 2, import.items.size

    get tool_import_path(import)
    assert_response :success
    assert_select ".import-item", 2
    assert_select "select#category_1 option[selected]", text: /Ladders & access/ # matched case-insensitively

    assert_difference("users(:one).tools.count", 1) do
      post confirm_tool_import_path(import), params: { items: {
        "0" => { include: "1", index: 0, name: "Red toolbox (big)", category_id: categories(:power).id, condition: "Good", description: "Red." },
        "1" => { include: "0", index: 1, name: "Blue case" }
      } }
    end
    assert_redirected_to dashboard_path
    assert import.reload.completed?

    tool = Tool.find_by!(name: "Red toolbox (big)")
    assert_equal categories(:power), tool.category
    photo = tool.photos.first
    photo.analyze
    # box 300x300px padded 6% each side -> 336x336
    assert_in_delta 336, photo.metadata["width"], 2
    assert_in_delta 336, photo.metadata["height"], 2
    # ...and it's the red tool, not the blue one or background
    image = Vips::Image.new_from_buffer(photo.download, "")
    red, green, blue = (0..2).map { |band| image.extract_band(band).avg }
    assert red > 150 && blue < 80 && green < 80, "expected crop to be mostly red, got #{[ red, green, blue ].map(&:round)}"
  end

  test "crop_for clamps padded boxes to the image" do
    sign_in_as users(:one)
    import = upload_and_analyze
    assert_equal [ 0, 0, 1000, 500 ], import.crop_for({ "photo_index" => 0, "box" => [ -50, 0, 1200, 1000 ] })
    assert_nil import.crop_for({ "photo_index" => 0, "box" => [ 1, 2 ] })
  end

  test "analysis failure is shown" do
    ToolPhotoAnalyzer.stub = ->(*) { raise ToolPhotoAnalyzer::Error, "The AI service is busy." }
    sign_in_as users(:one)
    import = upload_and_analyze
    assert import.reload.failed?
    get tool_import_path(import)
    assert_select ".flash", /busy/
  end

  test "rejects non-images" do
    sign_in_as users(:one)
    assert_no_difference("ToolImport.count") do
      post tool_imports_path, params: { tool_import: { photos: [ fixture_file_upload("notes.txt", "text/plain") ] } }
    end
    assert_response :unprocessable_entity
  end

  test "cannot see someone else's import" do
    sign_in_as users(:one)
    import = upload_and_analyze
    sign_in_as users(:two)
    get tool_import_path(import)
    assert_response :not_found
  end
end
