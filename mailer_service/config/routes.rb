Rails.application.routes.draw do
  # Health check endpoint
  get 'health', to: proc { [200, { 'Content-Type' => 'application/json' }, [{ status: 'ok', service: 'mailer_service', timestamp: Time.current.iso8601 }.to_json]] }

  root to: redirect("#{ENV.fetch('WEB_SERVICE_URL')}/#{I18n.default_locale}"), status: 302
end
