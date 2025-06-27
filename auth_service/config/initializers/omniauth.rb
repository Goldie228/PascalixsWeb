Rails.application.config.middleware.use OmniAuth::Builder do
  # 1) Discord
  provider :discord,
    ENV["DISCORD_CLIENT_ID"],
    ENV["DISCORD_CLIENT_SECRET"],
    scope:                  "identify email",
    callback_path:          "/api/#{ENV.fetch("AUTH_VERSION", "v1")}/auth/discord/callback",
    provider_ignores_state: true

  # 2) Google / YouTube
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    {
      scope:         "email profile https://www.googleapis.com/auth/youtube.readonly",
      access_type:   "offline",
      prompt:        "consent",
      callback_path: "/api/#{ENV.fetch("AUTH_VERSION", "v1")}/integrations/youtube/callback",
      provider_ignores_state: true
    }
end

# Обработка ошибок OmniAuth
OmniAuth.config.on_failure = Proc.new do |env|
  req   = Rack::Request.new(env)
  locale = req.session["locale"] || I18n.default_locale.to_s
  failure_url = "/#{locale}/api/v1/auth/failure?message=#{env['omniauth.error.type']}"
  Rack::Response.new([], 302, "Location" => failure_url).finish
end
