module ToolShareMcp
  class MyShed < Base
    tool_name "my_shed"
    title "My shed overview"
    description "Everything for the current user: my tools and their status, borrow requests waiting for my answer, " \
                "tools I've lent out, things I'm borrowing or have asked for, and photo imports waiting for analysis."
    annotations(**READ_ONLY)
    input_schema(properties: {})

    def self.call(server_context:, **)
      user = user_from(server_context)
      ok({
        me: { name: user.name },
        my_tools: user.tools.includes(:user, :category, :photos_attachments, borrow_requests: :borrower).order(:name).map { |t| tool_json(t, user) },
        requests_waiting_for_me: user.incoming_requests.pending.includes(:borrower, tool: :user).map { |r| loan_json(r) },
        lent_out: user.incoming_requests.approved.includes(:borrower, tool: :user).order(:due_date).map { |r| loan_json(r) },
        my_borrowing: user.borrow_requests.open.includes(tool: :user).map { |r| loan_json(r) },
        photo_imports_waiting: user.tool_imports.awaiting_assistant.count
      })
    end
  end
end
