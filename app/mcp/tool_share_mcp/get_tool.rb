module ToolShareMcp
  class GetTool < Base
    tool_name "get_tool"
    title "Get tool details"
    description "Full details of one tool. For your own tools this includes the check-out history."
    annotations(**READ_ONLY)
    input_schema(properties: { tool_id: { type: "integer" } }, required: [ "tool_id" ])

    def self.call(tool_id:, server_context:, **)
      user = user_from(server_context)
      tool = Tool.includes(:user, :category, borrow_requests: :borrower).find_by(id: tool_id) or return error_response("No tool with id #{tool_id}.")
      data = tool_json(tool, user)
      if tool.owned_by?(user)
        data[:history] = tool.borrow_requests.where(status: %w[approved returned]).order(created_at: :desc).limit(20).map do |loan|
          { borrower: loan.borrower_display_name, out: loan.start_date.iso8601, due: loan.due_date.iso8601,
            returned: loan.returned_at&.to_date&.iso8601 }.compact
        end
      end
      ok(data)
    end
  end
end
