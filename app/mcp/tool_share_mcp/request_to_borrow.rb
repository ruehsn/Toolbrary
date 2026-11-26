module ToolShareMcp
  class RequestToBorrow < Base
    tool_name "request_to_borrow"
    title "Ask to borrow someone's tool"
    description "Send the tool's owner a borrow request for the given dates. They approve or decline it."
    annotations(**WRITES)
    input_schema(
      properties: {
        tool_id: { type: "integer" },
        start_date: { type: "string", format: "date" },
        due_date: { type: "string", format: "date", description: "When it will be returned" },
        message: { type: "string", description: "Short note to the owner" }
      },
      required: %w[tool_id start_date due_date]
    )

    def self.call(tool_id:, start_date:, due_date:, server_context:, message: nil, **)
      user = user_from(server_context)
      tool = Tool.find_by(id: tool_id) or return error_response("No tool with id #{tool_id}.")
      if tool.borrow_requests.open.exists?(borrower: user)
        return error_response("You already have an open request for “#{tool.name}”.")
      end
      request = tool.borrow_requests.new(borrower: user, message: message.to_s.first(1000),
                                         start_date: parse_date(start_date, "start_date"), due_date: parse_date(due_date, "due_date"))
      return error_response(request.errors.full_messages.to_sentence) unless request.save
      ok(loan_json(request), "Request sent to #{tool.user.name}.")
    rescue ArgumentError => e
      error_response(e.message)
    end
  end
end
