module ToolbraryMcp
  class ListPhotoImports < Base
    tool_name "list_photo_imports"
    title "List photo imports waiting for analysis"
    description "Photo batches the user uploaded for their AI assistant to catalogue. Next: get_import_photo for each photo."
    annotations(**READ_ONLY)
    input_schema(properties: {})

    def self.call(server_context:, **)
      imports = user_from(server_context).tool_imports.awaiting_assistant.order(:created_at).map do |imp|
        { import_id: imp.id, photos: imp.photos.size, uploaded_at: imp.created_at.iso8601 }
      end
      ok({ imports: imports }, imports.empty? ? "No photo imports are waiting. The user can upload photos on the website (Dashboard → Add from photos)." : nil)
    end
  end
end
