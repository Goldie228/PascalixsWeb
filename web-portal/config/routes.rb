Rails.application.routes.draw do
  # Health check endpoint
  get 'health', to: proc { [200, { 'Content-Type' => 'application/json' }, [{ status: 'ok', service: 'web-portal', timestamp: Time.current.iso8601 }.to_json]] }

  root to: redirect("/#{I18n.default_locale}", status: 302)

  get "/load_punishment_appeal/:id", to: "user#load_punishment_appeal", as: :load_punishment_appeal
  post "/send_punishment_appeal/:id", to: "user#send_punishment_appeal", as: :send_punishment_appeal
  delete "/send_punishment_appeal_revoke/:id", to: "user#send_punishment_appeal_revoke", as: :send_punishment_appeal_revoke

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Статические страницы
    get "goodbye", to: "pages#goodbye", as: :goodbye
    root to: "pages#home", as: :localized_root

    # Редиректы для аутентификации
    get "/auth/discord",
    to: redirect("#{ENV["IDENTITY_SERVICE_URL"]}/%{locale}/api/#{ENV["AUTH_VERSION"]}/auth/discord", status: 302),
    as: :discord_auth

    # Редиректы для привязки аккаунтов
    get "/integrations/youtube",
    to: redirect("#{ENV["IDENTITY_SERVICE_URL"]}/%{locale}/api/#{ENV["AUTH_VERSION"]}/integrations/youtube", status: 302),
    as: :youtube_integration

    get "/integrations/tiktok",
    to: redirect("#{ENV["IDENTITY_SERVICE_URL"]}/%{locale}/api/#{ENV["AUTH_VERSION"]}/tiktok", status: 302),
    as: :tiktok_integration

    get "/integrations/twitch",
    to: redirect("#{ENV["IDENTITY_SERVICE_URL"]}/%{locale}/api/#{ENV["AUTH_VERSION"]}/integrations/twitch", status: 302),
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

    get "email_login", to: "sessions#email_login", as: :email_login
    post "email_login/verify_email", to: "sessions#verify_email", as: :email_login_verify
    get "email_login/pending", to: "pages#pending_email_login", as: :pending_email_login

    delete "/profile/youtube_unbind", to: "user#youtube_unbind", as: :youtube_unbind
    delete "/profile/tiktok_unbind", to: "user#tiktok_unbind", as: :tiktok_unbind
    delete "/profile/twitch_unbind", to: "user#twitch_unbind", as: :twitch_unbind

    get "/donate", to: "pages#donate", as: :donate
    get "/get_not_public_users", to: "user#get_not_public_users"
    get "/get_unban_price", to: "user#get_unban_price"
    get "/get_unmute_price", to: "user#get_unmute_price"

    # Донаты
    get "/my_donates", to: "user#donates", as: :donates

    # Спонсоры
    get "/sponsors", to: "user#sponsors", as: :sponsors

    # Галерея
    get "gallery", to: "pages#gallery", as: :gallery

    # Аккаунт
    get "account", to: "user#account", as: :user_account
    get "account/change_email", to: "user#change_email", as: :change_user_email
    get "account/change_email/pending_email_verification", to: "pages#pending_email_verification", as: :pending_email_verification
    get "prepare_password_reset", to: "user#prepare_password_reset", as: :prepare_password_reset
    get "account/change_password/pending_password_reset", to: "pages#pending_password_reset", as: :pending_password_reset
    get "confirm_email/:token", to: "pages#change_email_confirm", as: :change_email_confirm
    get "reset_password/:token", to: "user#reset_password", as: :reset_password
    post "validate_new_password", to: "user#validate_new_password", as: :validate_new_password
    post "account/change_email_process", to: "user#change_email_process"

    get "report/:id", to: "user#report"
    post "revoke_report/:id", to: "user#revoke_report"

    delete "account/delete", to: "user#delete_account", as: :delete_account

    # Админка
    get "admin/removed_players", to: "admin#removed_players", as: :admin_removed_players
    get "admin/players", to: "admin#players", as: :admin_players
    get "admin/players/:nickname/edit_player", to: "admin#edit_player", as: :admin_edit_player
    get "admin/punishment_appeals", to: "admin#punishment_appeals", as: :admin_punishment_appeals
    get "admin/appeals/:id", to: "admin#get_punishment_appeal"
    get "admin/get_appeal_data/:id", to: "admin#get_punishment_appeal_data"
    get "admin/complaints", to: "admin#complaints", as: :admin_complaints
    get "admin/purchases", to: "admin#purchases", as: :admin_purchases
    get "admin/products", to: "admin#products", as: :admin_products
    get "admin/avatars", to: "admin#avatars", as: :admin_avatars
    get "admin/gallery", to: "admin#gallery", as: :admin_gallery
    post "/admin/players/:nickname/punishments", to: "admin#add_punishment", as: :admin_add_punishment
    post "/admin/players/punishments/:nickname/cancel", to: "admin#cancel_punishment", as: :admin_cancel_punishment
    post "/admin/players/:nickname/change_password", to: "admin#change_password", as: :admin_change_password
    post "/admin/players/:nickname/update_account", to: "admin#update_account", as: :admin_update_account
    post "/admin/removed_players/add", to: "admin#add_to_removed_players", as: :admin_add_to_removed_players
    post "/admin/appeals_accept/:id", to: "admin#punishment_appeal_accept", as: :admin_punishment_appeals_accept
    post "/admin/reject_appeal", to: "admin#punishment_appeal_reject", as: :admin_punishment_appeal_reject
    delete "/admin/players/:nickname/delete_account", to: "admin#delete_account", as: :admin_delete_account
    delete "/admin/removed_players/:nickname/restore", to: "admin#restore_player", as: :admin_restore_player

    resources :purchases, only: [ :index, :create, :update, :destroy ]

    get "/admin/punishment_reasons", to: "admin#punishment_reasons", as: :admin_punishment_reasons
  end

  # API для межсервисного взаимодействия
  namespace :api do
    namespace :v1 do
      post "callbacks/auth_event", to: "callbacks#auth_event"
    end
  end
end
