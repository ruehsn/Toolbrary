module ToolbraryMcp
  class SearchTools < Base
    tool_name "search_tools"
    title "Search tools"
    description "Search the whole community's tools by keyword and/or category. Returns availability and owner."
    annotations(**READ_ONLY)
    input_schema(
      properties: {
        query: { type: "string", description: "Words to match in the tool name or description" },
        category: { type: "string", description: "Category name, see list_categories" },
        available_only: { type: "boolean", description: "Only tools not currently checked out" },
        limit: { type: "integer", minimum: 1, maximum: 100, description: "Default 25" }
      }
    )

    def self.call(server_context:, query: nil, category: nil, available_only: false, limit: 25, **)
      user = user_from(server_context)
      tools = Tool.includes(:user, :category, :borrow_requests, :photos_attachments).search(query).order(:name)
      if category.present?
        cat = Category.where("LOWER(name) = ?", category.downcase).first
        return error_response("Unknown category “#{category}”. Use list_categories.") unless cat
        tools = tools.where(category: cat)
      end
      tools = tools.available if available_only
      results = tools.limit(limit.to_i.clamp(1, 100)).map { |t| tool_json(t, user) }
      ok({ tools: results }, "#{results.size} tool(s) found.")
    end
  end
end
