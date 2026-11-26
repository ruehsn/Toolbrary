module ToolShareMcp
  class RespondToBorrowRequest < Base
    tool_name "respond_to_borrow_request"
    title "Approve or decline a borrow request"
    description "Answer a request someone made to borrow one of the user's tools (see my_shed). Approving checks the tool out to them."
    annotations(**WRITES)
    input_schema(
      properties: { request_id: { type: "integer" }, decision: { type: "string", enum: %w[approve decline] } },
      required: %w[request_id decision]
    )

    def self.call(request_id:, decision:, server_context:, **)
      request = user_from(server_context).incoming_requests.pending.find_by(id: request_id) or
        return error_response("No pending request #{request_id} for your tools.")
      decision == "approve" ? request.approve! : request.decline!
      ok(loan_json(request), "Request #{request.status}.")
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.record.errors.full_messages.to_sentence)
    end
  end
end
