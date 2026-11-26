module ToolShareMcp
  class GetImportPhoto < Base
    MAX_EDGE = 1568

    tool_name "get_import_photo"
    title "View a photo from an import"
    description "Returns one uploaded photo as an image so you can identify the tools in it."
    annotations(**READ_ONLY)
    input_schema(
      properties: { import_id: { type: "integer" }, photo_index: { type: "integer", minimum: 0, description: "0-based" } },
      required: %w[import_id photo_index]
    )

    def self.call(import_id:, photo_index:, server_context:, **)
      import = user_from(server_context).tool_imports.find_by(id: import_id) or return error_response("No import #{import_id}.")
      photo = import.photos[photo_index.to_i] or return error_response("Import #{import_id} has photos 0 to #{import.photos.size - 1}.")
      # Upright (EXIF-rotated) and downscaled: boxes are relative to this image, which matches how we crop.
      data = photo.blob.open do |file|
        jpeg = ImageProcessing::Vips.source(file.path).resize_to_limit(MAX_EDGE, MAX_EDGE).convert("jpg").saver(quality: 85).call
        Base64.strict_encode64(File.binread(jpeg.path)).tap { jpeg.close! }
      end
      MCP::Tool::Response.new([
        { type: "text", text: "Photo #{photo_index} of #{import.photos.size - 1} (0-based) in import #{import_id}. " \
                              "Give each tool's box as [x_min, y_min, x_max, y_max] on a 0-1000 scale of this image's width and height." },
        { type: "image", data: data, mimeType: "image/jpeg" }
      ])
    end
  end
end
