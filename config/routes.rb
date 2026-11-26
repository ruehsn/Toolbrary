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

  resources :tools do
    resources :borrow_requests, only: :create
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
