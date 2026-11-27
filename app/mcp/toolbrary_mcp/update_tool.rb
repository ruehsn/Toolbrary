module ToolbraryMcp
  class UpdateTool < Base
    tool_name "update_tool"
    title "Edit one of my tools"
    description "Change details of a tool the user owns. Only the fields you pass are changed."
    annotations(**WRITES, idempotent_hint: true)
    input_schema(
      properties: {
        tool_id: { type: "integer" },
        name: { type: "string", maxLength: 100 },
        category: { type: "string" },
        condition: { type: "string", enum: Tool::CONDITIONS },
        description: { type: "string" },
        replacement_url: { type: "string", description: "https:// link, or empty string to remove" }
      },
      required: [ "tool_id" ]
    )

    def self.call(tool_id:, server_context:, category: nil, **changes)
      tool = user_from(server_context).tools.find_by(id: tool_id) or return error_response("You don't own a tool with id #{tool_id}.")
      tool.assign_attributes(changes.slice(:name, :condition, :description, :replacement_url).compact)
      tool.new_category_name = category if category.present?
      return error_response(tool.errors.full_messages.to_sentence) unless tool.save
      ok(tool_json(tool, tool.user), "Updated “#{tool.name}”.")
    end
  end
end
