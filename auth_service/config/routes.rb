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
      # Discord OAuth
      get "/auth/discord/callback", to: "auth#discord_callback", as: :discord_callback
      # Youtube OAuth
      get "/integrations/youtube/callback", to: "integrations#youtube_callback", as: :youtube_callback
      # TikTok OAuth
      get "/integrations/tiktok/callback", to: "tiktok#callback", as: :tiktok_callback
      # Twitch OAuth
      get "/integrations/twitch/callback", to: "integrations#twitch_callback", as: :twitch_callback

      get "/players/:nickname", to: "user#public_profile", as: :public_profile
      get "/players/:nickname/punishments", to: "user#punishment_history", as: :punishment_history
      post "/players/:nickname/validate_password", to: "user#validate_password"
      get "/users/:user_id/get_password", to: "user#get_password"
      get "/users/:user_id", to: "user#get_user_data"
      get "/removed_players", to: "droped_user#all"
      post "/removed_players/add/:nickname", to: "droped_user#add"
    end
  end
end
