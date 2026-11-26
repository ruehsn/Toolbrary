module ToolShareMcp
  class CheckOutTool < Base
    tool_name "check_out_tool"
    title "Check out one of my tools"
    description "Record that someone now has one of the user's tools. Give borrower_email for a Tool Share member, " \
                "or just borrower_name for anyone else."
    annotations(**WRITES)
    input_schema(
      properties: {
        tool_id: { type: "integer" },
        borrower_name: { type: "string" },
        borrower_email: { type: "string" },
        due_date: { type: "string", format: "date", description: "YYYY-MM-DD" }
      },
      required: [ "tool_id", "due_date" ]
    )

    def self.call(tool_id:, due_date:, server_context:, borrower_name: nil, borrower_email: nil, **)
      tool = user_from(server_context).tools.find_by(id: tool_id) or return error_response("You don't own a tool with id #{tool_id}.")
      loan = tool.borrow_requests.new(status: "approved", start_date: Date.current, due_date: parse_date(due_date, "due_date"),
                                      borrower_name: borrower_name.to_s.squish.presence)
      if borrower_email.present?
        loan.borrower = User.find_by(email_address: borrower_email.strip.downcase) or
          return error_response("No member has that email. Use borrower_name instead.")
      end
      return error_response(loan.errors.full_messages.to_sentence) unless loan.save
      ok(loan_json(loan), "Checked out “#{tool.name}” to #{loan.borrower_display_name}.")
    rescue ArgumentError => e
      error_response(e.message)
    end
  end
end
