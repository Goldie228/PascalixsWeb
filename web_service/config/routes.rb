Rails.application.routes.draw do
  root to: redirect("/#{I18n.default_locale}", status: 302)

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Статические страницы
    get "pages/home", to: "pages#home", as: :home
    root to: "pages#home", as: :localized_root

    # Редиректы для аутентификации
    get '/auth/discord', 
    to: redirect("#{ENV['AUTH_SERVICE_URL']}/%{locale}/#{ENV['AUTH_VERSION']}/auth/discord", status: 302),
    as: :discord_auth

    # Профиль и настройки
    get 'profile', to: 'user#show', as: :user_profile
    post '/update_timezone', to: 'pages#update_timezone'

    get "/login", to: "sessions#new", as: :login
    post "/login", to: "sessions#create"
    delete "/logout", to: "sessions#destroy", as: :logout
  end

  # API для межсервисного взаимодействия
  namespace :api do
    namespace :v1 do
      post 'callbacks/auth_event', to: 'callbacks#auth_event'
    end
  end
end