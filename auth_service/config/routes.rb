Rails.application.routes.draw do
  # Перенаправление корневых маршрутов на web_service
  root to: redirect("#{ENV.fetch('WEB_SERVICE_URL')}/#{I18n.default_locale}"), status: 302
  get '/:locale', to: redirect("#{ENV.fetch('WEB_SERVICE_URL')}/%{locale}"), 
      constraints: { locale: /#{I18n.available_locales.join("|")}/ }, 
      status: 302

  # Все маршруты аутентификации
  scope "/:locale", locale: /#{I18n.available_locales.join("|")}/ do
    root to: redirect("#{ENV.fetch('WEB_SERVICE_URL')}/%{locale}"), as: :localized_root, status: 302

    namespace :api do
      namespace :v1 do
        # Сессии
        get "/login", to: "sessions#new", as: :login
        post "/login", to: "sessions#create"
        delete "/logout", to: "sessions#destroy", as: :logout

        get "/auth/discord", to: "auth#discord", as: :discord_auth
        get '/auth/failure', to: 'auth#failure'

        get 'users/fields', to: 'users#invalid_request'
        get 'users//fields', to: 'users#invalid_request'
        get 'me/fields', to: 'users#current_user_fields'

        resources :users, only: [] do
          member do
            get :fields
          end
        end

        get "/auth/register_minecraft", 
        to: redirect("#{ENV['WEB_SERVICE_URL']}/%{locale}/auth/register_minecraft", status: 302),
        as: :register_minecraft
        
        # Двухфакторная аутентификация
        get 'two_factor_authentication', to: 'two_factor_authentications#show'
        post 'two_factor_authentication/verify', to: 'two_factor_authentications#verify'
        post 'two_factor_authentication/resend_code', to: 'two_factor_authentications#resend_code'
      end
    end
  end

  namespace :api do
    namespace :v1 do
      # Discord OAuth
      get "/auth/discord/callback", to: "auth#discord_callback", as: :discord_callback
    end
  end
end