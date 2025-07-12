Rails.application.routes.draw do
  root to: redirect("/#{I18n.default_locale}", status: 302)

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Статические страницы
    get "pages/home", to: "pages#home", as: :home
    root to: "pages#home", as: :localized_root

    # Редиректы для аутентификации
    get "/auth/discord",
    to: redirect("#{ENV["AUTH_SERVICE_URL"]}/%{locale}/api/#{ENV["AUTH_VERSION"]}/auth/discord", status: 302),
    as: :discord_auth

    # Редиректы для привязки аккаунтов
    get "/integrations/youtube",
    to: redirect("#{ENV["AUTH_SERVICE_URL"]}/%{locale}/api/#{ENV["AUTH_VERSION"]}/integrations/youtube", status: 302),
    as: :youtube_integration

    get "/integrations/tiktok",
    to: redirect("#{ENV["AUTH_SERVICE_URL"]}/%{locale}/api/#{ENV["AUTH_VERSION"]}/tiktok", status: 302),
    as: :tiktok_integration

    get "/integrations/twitch",
    to: redirect("#{ENV["AUTH_SERVICE_URL"]}/%{locale}/api/#{ENV["AUTH_VERSION"]}/integrations/twitch", status: 302),
    as: :twitch_integration

    get "/auth/register_minecraft", to: "auth#register_minecraft", as: :register_minecraft_form
    post "/auth/register_minecraft", to: "auth#submit_registration", as: :register_minecraft

    # Профиль и настройки
    get "profile", to: "user#show", as: :user_profile
    get "/players/:nickname", to: "user#public_profile", as: :public_profile
    get "players", to: "user#players", as: :players
    post "profile/update_about_me", to: "user#update_about_me", as: :update_about_me
    post "/update_timezone", to: "pages#update_timezone"

    get "two_factor_authentication", to: "two_factor_authentications#show", as: :user_two_factor_authentication
    get "two_factor_authentication/check_status", to: "two_factor_autications#check_status"
    post "two_factor_authentication/verify", to: "two_factor_authentications#verify", as: :verify_two_factor_authentication
    post "two_factor_authentication/resend_code", to: "two_factor_authentications#resend_code", as: :resend_two_factor_code
    post "two_factor_success", to: "two_factor_authentications#success_update"

    get "/login", to: "sessions#new", as: :login
    post "/login", to: "sessions#create"
    post "/update_session", to: "sessions#update"
    delete "/logout", to: "sessions#destroy", as: :logout

    delete "/profile/youtube_unbind", to: "user#youtube_unbind", as: :youtube_unbind
    delete "/profile/tiktok_unbind", to: "user#tiktok_unbind", as: :tiktok_unbind
    delete "/profile/twitch_unbind", to: "user#twitch_unbind", as: :twitch_unbind

    # Админка
    get "admin/players", to: "admin#players", as: :admin_players
    get "admin/players/:nickname/edit_player", to: "admin#edit_player", as: :admin_edit_player
    post "/admin/players/:nickname/punishments", to: "admin#add_punishment", as: :admin_add_punishment
    post "/admin/players/punishments/:nickname/cancel", to: "admin#cancel_punishment", as: :admin_cancel_punishment
    post "/admin/players/:nickname/change_password", to: "admin#change_password", as: :admin_change_password
  end

  # API для межсервисного взаимодействия
  namespace :api do
    namespace :v1 do
      post "callbacks/auth_event", to: "callbacks#auth_event"
    end
  end
end
