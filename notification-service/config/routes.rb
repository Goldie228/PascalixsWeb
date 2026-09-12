Rails.application.routes.draw do
  # Health check endpoint
  get 'health', to: proc { [200, { 'Content-Type' => 'application/json' }, [{ status: 'ok', service: 'notification-service', timestamp: Time.current.iso8601 }.to_json]] }

  web_portal_url = ENV.fetch('WEB_PORTAL_URL', 'http://localhost:3000')
  root to: redirect("#{web_portal_url}/#{I18n.default_locale}"), status: 302
end
