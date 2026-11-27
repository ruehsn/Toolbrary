module ToolbraryMcp
  class CheckInTool < Base
    tool_name "check_in_tool"
    title "Check in one of my tools"
    description "Record that one of the user's tools has come back."
    annotations(**WRITES, idempotent_hint: true)
    input_schema(properties: { tool_id: { type: "integer" } }, required: [ "tool_id" ])

    def self.call(tool_id:, server_context:, **)
      tool = user_from(server_context).tools.find_by(id: tool_id) or return error_response("You don't own a tool with id #{tool_id}.")
      loan = tool.borrow_requests.approved.first or return error_response("“#{tool.name}” isn't checked out.")
      loan.mark_returned!
      ok(loan_json(loan), "Checked in “#{tool.name}” from #{loan.borrower_display_name}.")
    end
  end
end
