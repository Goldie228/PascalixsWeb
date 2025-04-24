Rails.application.routes.draw do
  # Перенаправление на web_service для фронтенд маршрутов
  get '/', to: redirect('http://localhost:3001/')
  get '/ru', to: redirect('http://localhost:3001/ru')
  get '/en', to: redirect('http://localhost:3001/en')

  # Добавляем прямой маршрут для Discord OAuth без привязки к локали
  get "/v1/auth/discord", to: "v1/auth#discord"
  get "/v1/auth/discord/callback", to: "v1/auth#discord_callback"
  
  # Добавляем совместимость со старым путем
  get "/auth/discord", to: "v1/auth#discord"
  get "/auth/discord/callback", to: "v1/auth#discord_callback"

  namespace :v1 do
    scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
      get "/auth/discord", to: "auth#discord", as: :discord_auth
      get "/auth/discord/callback", to: "auth#discord_callback"
      get "/auth/register_minecraft", to: "auth#register_minecraft"
      post "/auth/register_minecraft", to: "auth#register_minecraft", as: :register_minecraft

      get "/login", to: "sessions#new", as: :login
      post "/login", to: "sessions#create"
      delete "/logout", to: "sessions#destroy", as: :logout

      get 'two_factor_authentication', to: 'two_factor_authentications#show', as: :user_two_factor_authentication
      post 'two_factor_authentication/verify', to: 'two_factor_authentications#verify', as: :verify_two_factor_authentication
      post 'two_factor_authentication/resend_code', to: 'two_factor_authentications#resend_code', as: :resend_two_factor_code
    end
  end

  scope '/api/v1' do
    post 'register', to: 'auth#register'
    post 'login', to: 'auth#login'
    delete 'logout', to: 'auth#logout'
    get 'me', to: 'auth#me'
    get 'verify_token', to: 'auth#verify_token'
  end
end
