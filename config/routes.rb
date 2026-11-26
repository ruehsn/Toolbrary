Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

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

  get "up" => "rails/health#show", as: :rails_health_check

  root "tools#index"
end
