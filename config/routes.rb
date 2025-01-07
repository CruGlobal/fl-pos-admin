require 'sidekiq/pro/web'
require 'sidekiq/cron/web'
require 'sidekiq_unique_jobs/web'

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "monitors/lb" => "monitors#lb", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  constraints ->(request) { user_constraint(request) } do
    mount Sidekiq::Web => "/sidekiq"
  end

  def user_constraint(request)
    omniauth = request.session[:omniauth_hash]
    user_guid = omniauth&.extra&.raw_info&.ssoguid&.upcase
    User.find_by(guid: user_guid) if user_guid.present?
  end
end
