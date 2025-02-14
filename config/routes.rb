require "sidekiq/pro/web"
require "sidekiq/cron/web"
require "sidekiq_unique_jobs/web"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "monitors/lb" => "monitors#lb", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "jobs#index"

  # Lightspeed handlers
  match "/lightspeedinit", to: "lightspeedinit#index", via: [:get]
  match "/lightspeedauth", to: "lightspeedauth#index", via: [:get]

  resources :jobs do
    member do
      post :restart
    end
  end
  get "/jobs", to: "jobs#index"
  match "/google_sheets", to: "google_sheets#index", via: [:get]
  match "/google_sheets/import", to: "google_sheets#import", via: [:post]

  match "/logout", to: "sessions#destroy", as: :logout, via: [:get, :post, :delete]
  get "auth/:provider/callback", to: "sessions#create"
  resource :session, only: %i[new create destroy]

  constraints ->(request) { user_constraint(request) } do
    mount Sidekiq::Web => "/sidekiq"
  end

  def user_constraint(request)
    request.session[:id_token].present?
  end
end
