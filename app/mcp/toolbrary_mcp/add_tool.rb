module ToolbraryMcp
  class AddTool < Base
    tool_name "add_tool"
    title "Add a tool to my shed"
    description "List a new tool the user owns. Use an existing category name where possible (list_categories); " \
                "a new name creates a category. Photos are added on the website or through a photo import."
    annotations(**WRITES)
    input_schema(
      properties: {
        name: { type: "string", maxLength: 100 },
        category: { type: "string" },
        condition: { type: "string", enum: Tool::CONDITIONS },
        description: { type: "string", description: "Notes for borrowers" },
        replacement_url: { type: "string", description: "Optional https:// link to buy a replacement" }
      },
      required: [ "name" ]
    )

    def self.call(name:, server_context:, category: nil, condition: nil, description: nil, replacement_url: nil, **)
      tool = user_from(server_context).tools.new(name:, condition:, description:, replacement_url:, new_category_name: category)
      return error_response(tool.errors.full_messages.to_sentence) unless tool.save
      ok(tool_json(tool, tool.user), "Added “#{tool.name}”.")
    end
  end
end
