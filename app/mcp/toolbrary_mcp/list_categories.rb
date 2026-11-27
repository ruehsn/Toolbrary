module ToolbraryMcp
  class ListCategories < Base
    tool_name "list_categories"
    title "List categories"
    description "All tool categories with how many tools each has."
    annotations(**READ_ONLY)
    input_schema(properties: {})

    def self.call(server_context:, **)
      counts = Tool.group(:category_id).count
      ok({ categories: Category.alphabetical.map { |c| { name: c.name, icon: c.icon, tools: counts[c.id].to_i } } })
    end
  end
end
