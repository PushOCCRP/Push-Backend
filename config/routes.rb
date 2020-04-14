Rails.application.routes.draw do
  devise_for :users
  root to: "home#index"

  get "admin" => "administration#index"

  get "notifications" => "notifications#index"
  get "notifications/admin" => "notifications#admin"

  post "notifications/subscribe" => "notifications#subscribe"
  post "notifications/unsubscribe" => "notifications#unsubscribe"
  get "notifications/resubscribe" => "notifications#resubscribe"

  get "notifications/cert_upload" => "notifications#cert_upload"
  post "notifications/cert_upload" => "notifications#process_cert"

  get "notifications/gcm" => "notifications#gcm"
  post "notifications/gcm" => "notifications#process_gcm"

  get "notifications/:id/push" => "notifications#push", as: :push
  resources :notifications

  resources :users

  get "articles" => "articles#index", defaults: { format: "json" }
  get "article" => "articles#article", defaults: { format: "json" }
  get "search" => "articles#search", defaults: { format: "json" }
  post "authenticate" => "subscriptions#authenticate", defaults: { format: "json" }
  post "logout" => "subscriptions#logout", defaults: { format: "json" }

  get "preferences" => "preferences#index"
  put "preferences" => "preferences#update"

  get "passthrough" => "application#passthrough"

  get "heartbeat" => "application#heartbeat"

  get "analytics" => "analytics#index"
end
