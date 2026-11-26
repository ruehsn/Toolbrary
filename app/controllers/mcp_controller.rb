# Streamable HTTP endpoint for the MCP server (stateless, JSON responses).
# Auth: "Authorization: Bearer tsk_..." personal token from the Account page.
class McpController < ActionController::API
  rate_limit to: 120, within: 1.minute, by: -> { request.authorization.to_s.last(16).presence || request.remote_ip },
             with: -> { render json: rpc_error(-32000, "Rate limit exceeded, slow down."), status: :too_many_requests }

  def handle
    token = ApiToken.authenticate(request.authorization.to_s[/\ABearer (.+)\z/, 1])
    unless token
      response.headers["WWW-Authenticate"] = %(Bearer realm="Tool Share", error="invalid_token")
      return render json: rpc_error(-32001, "Missing or invalid API token. Create one under Account → AI assistants."), status: :unauthorized
    end

    server = ToolShareMcp.server_for(token.user)
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server, stateless: true, enable_json_response: true, allowed_hosts: ToolShareMcp.allowed_hosts
    )
    status, headers, body = transport.call(request.env)
    headers.each { |key, value| response.headers[key] = value }
    self.status = status
    self.response_body = body
  end

  private
    def rpc_error(code, message) = { jsonrpc: "2.0", id: nil, error: { code: code, message: message } }
end
