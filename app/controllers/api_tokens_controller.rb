class ApiTokensController < ApplicationController
  def create
    @api_token = Current.user.api_tokens.new(name: params.dig(:api_token, :name).presence || "AI assistant")
    if @api_token.save
      # Rendered (not redirected) so the plain token is never stored in the session cookie.
      render :created
    else
      redirect_to account_path, alert: @api_token.errors.full_messages.to_sentence
    end
  end

  def destroy
    Current.user.api_tokens.find(params[:id]).destroy
    redirect_to account_path(anchor: "ai-assistants"), notice: "Token revoked. Assistants using it can no longer connect.", status: :see_other
  end
end
