Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  # Serve API documentation
  get '/api-docs', to: redirect('/api-docs/index.html')

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      # Authentication routes
      post 'auth/login', to: 'authentication#login'
      post 'auth/logout', to: 'authentication#logout'
      post 'auth/refresh', to: 'authentication#refresh'

      # Production Orders routes with nested tasks
      resources :production_orders do
        member do
          get :tasks_summary
          get :audit_logs
        end
        
        # Nested tasks routes
        resources :tasks, except: [:index, :show] do
          member do
            patch :complete
            patch :reopen
          end
        end

        collection do
          get :urgent_orders_report
          get :monthly_statistics
          get :urgent_with_expired_tasks
        end
      end

      # Separate routes for different order types
      resources :normal_orders, controller: :production_orders, type: 'NormalOrder'
      resources :urgent_orders, controller: :production_orders, type: 'UrgentOrder'

      # Order assignments
      resources :order_assignments, only: [:create, :destroy]

      # Users management (basic CRUD)
      resources :users, only: [:index, :show, :create, :update, :destroy]

      # Health check for API
      get 'health', to: 'application#health'
    end
  end
end