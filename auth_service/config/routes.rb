Rails.application.routes.draw do
  # Перенаправление корневых маршрутов на web_service
  root to: redirect("#{ENV.fetch('WEB_SERVICE_URL')}/#{I18n.default_locale}"), status: 302
  get '/:locale', to: redirect("#{ENV.fetch('WEB_SERVICE_URL')}/%{locale}"), 
      constraints: { locale: /#{I18n.available_locales.join("|")}/ }, 
      status: 302

  # Все маршруты аутентификации
  scope "/:locale", locale: /#{I18n.available_locales.join("|")}/ do
    root to: redirect("#{ENV.fetch('WEB_SERVICE_URL')}/%{locale}"), as: :localized_root, status: 302

    namespace :v1 do
      # Discord OAuth
      get "/auth/discord", to: "auth#discord", as: :discord_auth
      get "/auth/discord/callback", to: "auth#discord_callback"
      
      # Сессии
      get "/login", to: "sessions#new", as: :login
      post "/login", to: "sessions#create"
      delete "/logout", to: "sessions#destroy", as: :logout
      
      # Двухфакторная аутентификация
      get 'two_factor_authentication', to: 'two_factor_authentications#show'
      post 'two_factor_authentication/verify', to: 'two_factor_authentications#verify'
      post 'two_factor_authentication/resend_code', to: 'two_factor_authentications#resend_code'
    end
  end

  # API без локали
  namespace :api do
    namespace :v1 do
      post 'register', to: 'auth#register'
      post 'login', to: 'auth#login'
      delete 'logout', to: 'auth#logout'
      get 'me', to: 'auth#me'
      get 'verify_token', to: 'auth#verify_token'
    end
  end
end