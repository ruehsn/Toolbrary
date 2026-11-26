class AccountsController < ApplicationController
  def show
    @user = Current.user
    @passkeys = @user.passkeys.order(:created_at)
    @api_tokens = @user.api_tokens.order(:created_at)
  end

  def update
    @user = Current.user
    if @user.update(params.expect(user: [ :name ]))
      redirect_to account_path, notice: "Name updated."
    else
      @passkeys = @user.passkeys.order(:created_at)
      @api_tokens = @user.api_tokens.order(:created_at)
      render :show, status: :unprocessable_entity
    end
  end
end
