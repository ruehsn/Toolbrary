module ToolbraryMcp
  # Shared helpers for Toolbrary MCP tools.
  class Base < MCP::Tool
    READ_ONLY = { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false }.freeze
    WRITES = { read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false }.freeze

    class << self
      include Rails.application.routes.url_helpers

      private
        def user_from(server_context) = server_context[:user]

        def ok(data, summary = nil)
          text = [ summary, JSON.pretty_generate(data) ].compact.join("\n\n")
          MCP::Tool::Response.new([ { type: "text", text: text } ], structured_content: data)
        end

        def error_response(message)
          MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
        end

        def parse_date(value, field)
          Date.iso8601(value.to_s)
        rescue Date::Error
          raise ArgumentError, "#{field} must be a date like 2026-12-31"
        end

        def tool_status(tool)
          loan = tool.current_loan
          return { status: "available" } unless loan
          { status: loan.overdue? ? "overdue" : "checked_out", due_back: loan.due_date.iso8601 }
        end

        def tool_json(tool, viewer)
          mine = tool.owned_by?(viewer)
          data = {
            id: tool.id, name: tool.name, category: tool.category&.name, condition: tool.condition,
            description: tool.description, owner: tool.user.name, mine: mine,
            photos: tool.photos.size, replacement_url: tool.replacement_url, url: tool_url(tool)
          }.merge(tool_status(tool))
          if mine && (loan = tool.current_loan)
            data[:checked_out_to] = loan.borrower_display_name
          end
          data.compact
        end

        def loan_json(loan)
          {
            request_id: loan.id, tool_id: loan.tool_id, tool: loan.tool.name, status: loan.status,
            borrower: loan.borrower_display_name, owner: loan.owner.name,
            start_date: loan.start_date.iso8601, due_date: loan.due_date.iso8601,
            message: loan.message.presence, overdue: loan.overdue? || nil
          }.compact
        end
    end
  end
end
