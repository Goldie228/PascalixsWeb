
Rails.application.routes.draw do
  # Перенаправление корневых маршрутов на web_service
  root to: redirect("#{ENV.fetch("WEB_SERVICE_URL")}/#{I18n.default_locale}"), status: 302
  get "/:locale", to: redirect("#{ENV.fetch("WEB_SERVICE_URL")}/%{locale}"),
      constraints: { locale: /#{I18n.available_locales.join("|")}/ },
      status: 302

  # Все маршруты аутентификации
  scope "/:locale", locale: /#{I18n.available_locales.join("|")}/ do
    root to: redirect("#{ENV.fetch("WEB_SERVICE_URL")}/%{locale}"), as: :localized_root, status: 302
    get "/profile", to: redirect("#{ENV.fetch("WEB_SERVICE_URL")}/%{locale}/profile"), as: :profile, status: 302

    namespace :api do
      namespace :v1 do
        # Сессии
        get "/login", to: "sessions#new", as: :login
        post "/login", to: "sessions#create"
        delete "/logout", to: "sessions#destroy", as: :logout

        get "/auth/discord", to: "auth#discord", as: :discord_auth
        get "/auth/failure", to: "auth#failure"

        # Интеграции
        get "/integrations/youtube",         to: "integrations#youtube",  as: :youtube_integration
        get "/integrations/youtube/failure", to: "integrations#failure",  as: :youtube_integration_failure

        get "/integrations/tiktok/failure", to: "tiktok#failure",  as: :tiktok_integration_failure

        get "/integrations/twitch",         to: "integrations#twitch",  as: :twitch_integration
        get "/integrations/twitch/failure", to: "integrations#failure",  as: :twitch_integration_failure

        get "/tiktok", to: "tiktok#start", as: :tiktok_integration
        post "/tiktok", to: "tiktok#start"

        post "/players/:nickname/validate_password", to: "user#validate_password"

        resources :users, only: [] do
          member do
            get :fields
          end
        end

        get "/auth/register_minecraft",
        to: redirect("#{ENV["WEB_SERVICE_URL"]}/%{locale}/auth/register_minecraft", status: 302),
        as: :register_minecraft

        # Двухфакторная аутентификация
        get "two_factor_authentication", to: "two_factor_authentications#show"
        post "two_factor_authentication/verify", to: "two_factor_authentications#verify"
        post "two_factor_authentication/resend_code", to: "two_factor_authentications#resend_code"
      end
    end
  end

  namespace :api do
    namespace :v1 do
      # OAuth callbacks
      get "/auth/discord/callback", to: "auth#discord_callback", as: :discord_callback
      get "/integrations/youtube/callback", to: "integrations#youtube_callback", as: :youtube_callback
      get "/integrations/tiktok/callback", to: "tiktok#callback", as: :tiktok_callback
      get "/integrations/twitch/callback", to: "integrations#twitch_callback", as: :twitch_callback

      # User & Punishment
      get "/players/:nickname", to: "user#public_profile", as: :public_profile
      get "/players/:nickname/punishments", to: "user#punishment_history", as: :punishment_history
      get "/players/:nickname/password_check", to: "user#password_check"
      post "/players/:nickname/validate_password", to: "user#validate_password"
      get "/users/:user_id/get_password", to: "user#get_password"
      get "/users/:user_id", to: "user#get_user_data"
      get "/removed_players", to: "droped_user#all"
      post "/removed_players/add/:nickname", to: "droped_user#add"
      get "/user/punishment_appeal/:id", to: "user_punishment_appeal#get_punishment_appeal"
      get "/user/punishment_appeal/full/:id", to: "user_punishment_appeal#show"
      get "/user/punishment_appeal_all", to: "user_punishment_appeal#all"
      get "/lookup_email", to: "user#lookup_email"
      get "/user/punishment_appeal/get_admin_answer/:id", to: "user_punishment_appeal#get_admin_answer"
      get "/admin/complaints", to: "reports#index"
      post "/user/punishment_appeal/reject", to: "user_punishment_appeal#admin_reject"
      delete "user/punishment_appeal/delete/:id", to: "user_punishment_appeal#delete"

      # Reports
      post '/user/add_report/:reported_user_id', to: 'reports#add_report'
      get 'reports/:id', to: 'reports#show'
      get 'admin/reports/:id', to: 'reports#admin_show'
      post 'reports/revoke/:id', to: 'reports#revoke'
      post 'admin/reports/:id/revoke', to: 'reports#admin_revoke'
      delete 'admin/reports/:id', to: 'reports#delete'
      put 'reports/:id', to: 'reports#update'

      # Products & Purchases
      get 'product/:product_type', to: 'product#show'
      get 'products', to: 'product#index'
      put 'product/:product_type', to: 'product#update'

      resources :purchases, only: [ :index, :create, :update, :destroy ]
      get 'purchases/all', to: 'purchases#admin_index'
      get 'purchases/:nickname', to: 'purchases#user_index'
      post 'purchase/:purchase_id/accept', to: 'purchases#accept'
      post 'purchase/:purchase_id/reject', to: 'purchases#reject'
      delete 'purchase/:purchase_id', to: 'purchases#destroy'

      # Punishment Reasons
      get 'punishment_reasons', to: 'punishment_reasons#index'
      get 'punishment_reasons/all', to: 'punishment_reasons#all'
      get 'punishment_reasons/:rule_number', to: 'punishment_reasons#show'
      post 'punishment_reasons', to: 'punishment_reasons#create'
      patch 'punishment_reasons/:rule_number', to: 'punishment_reasons#update'
      delete 'punishment_reasons/:rule_number', to: 'punishment_reasons#destroy'

      # Discord Avatars
      get 'discord_avatar/:user_id', to: 'discord_avatar#show'
      get 'discord_avatars/admin_index', to: 'discord_avatar#admin_index'
      post 'discord_avatar/:user_id', to: 'discord_avatar#create'
      patch 'discord_avatars/:id/approve', to: 'discord_avatar#approve'
      patch 'discord_avatars/:id/reject', to: 'discord_avatar#reject'
      delete 'discord_avatar/:user_id', to: 'discord_avatar#destroy'

      # Galleries
      put 'galleries', to: 'gallery#update'
      resources :galleries, only: [ :index, :create, :show, :update, :destroy ]

      # Wiki API
      namespace :wiki do
        resources :pages, param: :slug do
          collection do
            post :upload_temporary_image
            get :admin_index
            get :check_slug
            get :positions
            post :reorder
          end
          member do
            post :upload_image
          end

          resources :downloads, only: [:index, :create, :update, :destroy]
        end

        resources :categories, only: [:index, :create, :update, :destroy] do
          get :pages, on: :member
          collection do
            post :reorder
          end
        end
      end
    end
  end
end
