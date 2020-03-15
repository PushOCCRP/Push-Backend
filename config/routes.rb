# frozen_string_literal: true

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

  get "articles" => "articles#index", :defaults => { format: "json" }
  get "article" => "articles#article", :defaults => { format: "json" }
  get "search" => "articles#search", :defaults => { format: "json" }
  post "authenticate" => "subscriptions#authenticate", :defaults => { format: "json" }
  post "logout" => "subscriptions#logout", :defaults => { format: "json" }

  get "preferences" => "preferences#index"
  put "preferences" => "preferences#update"

  get "passthrough" => "application#passthrough"

  get "heartbeat" => "application#heartbeat"

  get "analytics" => "analytics#index"

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
