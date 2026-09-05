Rails.application.routes.draw do
  # Health check endpoint
  get 'health', to: proc { [200, { 'Content-Type' => 'application/json' }, [{ status: 'ok', service: 'game-service', timestamp: Time.current.iso8601 }.to_json]] }

  root to: redirect("#{ENV.fetch("WEB_PORTAL_URL")}/#{I18n.default_locale}"), status: 302
  get "/:locale", to: redirect("#{ENV.fetch("WEB_PORTAL_URL")}/%{locale}"),
      constraints: { locale: /#{I18n.available_locales.join("|")}/ },
      status: 302

  namespace :api do
    namespace :v1 do
      get "players/:nickname/check_password", to: "player#check_password"
    end
  end
end
