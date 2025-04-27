Rails.application.config.middleware.use OmniAuth::Builder do
  # Используем ENV переменные для конфигурации
  provider :discord,
           ENV["DISCORD_CLIENT_ID"],
           ENV["DISCORD_CLIENT_SECRET"],
           scope: "identify email",
           callback_path: "/ru/v1/auth/discord/callback",
           callback_url: ENV["DISCORD_CALLBACK_URL"],
           provider_ignores_state: true

  OmniAuth.config.on_failure = Proc.new do |env|
    V1::AuthController.action(:failure).call(env)
  end
end

# Настройка для безопасности в production
if Rails.env.production?
  OmniAuth.config.allowed_request_methods = [:post]
  # Защита от CSRF
  OmniAuth.config.request_validation_phase = ActionDispatch::Cookies::CookieOverflow.action(:diagnostics)
end 