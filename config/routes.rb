Rails.application.routes.draw do
  # Passwordless auth: magic links + passkeys
  resource :session, only: %i[new create destroy] do
    get :check_email
  end
  resource :registration, only: %i[new create]
  resource :magic_link, only: %i[show create]   # GET shows a confirm button, POST signs in
  resource :passkey_session, only: :create do
    post :options
  end
  resources :passkeys, only: %i[create update destroy] do
    post :options, on: :collection
  end
  resource :account, only: %i[show update]
  resources :api_tokens, only: %i[create destroy]

  # MCP server for AI assistants (see app/mcp)
  match "mcp", to: "mcp#handle", via: %i[get post delete]

  resources :tools do
    resources :borrow_requests, only: :create
    post :check_out, on: :member
  end
  resources :categories, only: %i[index create]
  resources :tool_imports, only: %i[new create show destroy] do
    post :confirm, on: :member
  end
  resources :borrow_requests, only: [] do
    member do
      patch :approve
      patch :decline
      patch :cancel
      patch :return
    end
  end
  resources :users, only: :show
  get "dashboard" => "dashboard#show", as: :dashboard

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  get "up" => "rails/health#show", as: :rails_health_check

  root "tools#index"
end
