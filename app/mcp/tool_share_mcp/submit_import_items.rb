module ToolShareMcp
  class SubmitImportItems < Base
    tool_name "submit_import_items"
    title "Submit the tools found in a photo import"
    description "Send every lendable tool you identified across all photos of one import, in a single call. " \
                "Nothing is added to the shed yet: the user reviews, edits and confirms on the returned review_url."
    annotations(**WRITES, idempotent_hint: true)
    input_schema(
      properties: {
        import_id: { type: "integer" },
        items: {
          type: "array",
          items: {
            type: "object",
            properties: {
              photo_index: { type: "integer", minimum: 0 },
              name: { type: "string", description: "What a borrower would search for, plus brand/model/size if clearly legible" },
              category: { type: "string", description: "Closest existing category name (list_categories)" },
              condition: { type: "string", enum: Tool::CONDITIONS },
              description: { type: "string", description: "1-2 sentences: use, visible accessories, anything a borrower should know" },
              box: { type: "array", items: { type: "number" }, minItems: 4, maxItems: 4,
                     description: "[x_min, y_min, x_max, y_max], 0-1000 scale, (0,0) = top-left" }
            },
            required: %w[photo_index name box]
          }
        }
      },
      required: %w[import_id items]
    )

    def self.call(import_id:, items:, server_context:, **)
      import = user_from(server_context).tool_imports.find_by(id: import_id) or return error_response("No import #{import_id}.")
      return error_response("Import #{import_id} was already #{import.status}.") unless import.awaiting_assistant? || import.ready?
      accepted = import.accept_items!(items)
      ok({ import_id: import.id, items_received: accepted.size, review_url: tool_import_url(import) },
         "Saved #{accepted.size} item(s). Ask the user to open review_url to check and add them.")
    end
  end
end
