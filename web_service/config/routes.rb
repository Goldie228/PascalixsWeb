Rails.application.routes.draw do
  root to: redirect("/#{I18n.default_locale}", status: 302), as: :redirected_root

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Страницы и авторизация
    get "pages/home", to: "pages#home"
    get "/auth/discord", to: redirect("#{ENV['AUTH_SERVICE_URL']}/auth/discord") if Rails.env.production?
    get "/auth/discord", to: "auth#discord", as: :discord_auth unless Rails.env.production?
    get "/login", to: "sessions#new", as: :login
    post "/login", to: "sessions#create"
    delete "/logout", to: "sessions#destroy", as: :logout

    # Редиректы для auth_service
    get "/auth/callback", to: "auth#callback"
    
    # Корневой маршрут с локализацией
    root to: "pages#home", as: :localized_root

    # Маршруты для 2FA
    get 'two_factor_authentication', to: 'two_factor_authentications#show', as: :user_two_factor_authentication
    post 'two_factor_authentication/verify', to: 'two_factor_authentications#verify', as: :verify_two_factor_authentication
    post 'two_factor_authentication/resend_code', to: 'two_factor_authentications#resend_code', as: :resend_two_factor_code

    # Настройки пользователя
    get 'profile', to: 'user#show', as: :user_profile
    
    # Настройки времени
    post '/update_timezone', to: 'pages#update_timezone'
  end

  # API для межсервисного взаимодействия
  namespace :api do
    namespace :v1 do
      post 'callbacks/auth_event', to: 'callbacks#auth_event'
      resources :auth, only: [] do
        collection do
          get :current_user
          post :login
          delete :logout
        end
      end
    end
  end

  # Редирект на страницу с локализацией по умолчанию
  root to: redirect { |params| "/#{I18n.default_locale}" }
end
