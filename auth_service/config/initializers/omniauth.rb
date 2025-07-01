OmniAuth.config.path_prefix = "/api/#{ENV.fetch("AUTH_VERSION", "v1")}/auth"
OmniAuth.config.allowed_request_methods = [ :get, :post ]
OmniAuth.config.logger = Rails.logger

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :discord,
    ENV["DISCORD_CLIENT_ID"],
    ENV["DISCORD_CLIENT_SECRET"],
    scope: "identify email",
    provider_ignores_state: true

  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    {
      scope: "email profile https://www.googleapis.com/auth/youtube.readonly",
      access_type: "offline",
      prompt: "consent",
      callback_path: "/api/#{ENV.fetch("AUTH_VERSION", "v1")}/integrations/youtube/callback",
      provider_ignores_state: true
    }
end

# Универсальный обработчик ошибок
OmniAuth.config.on_failure = Proc.new do |env|
  req      = Rack::Request.new(env)
  locale   = req.session["locale"] || I18n.default_locale.to_s
  strategy = env["omniauth.error.strategy"]
  name     = strategy.name.to_s

  segment = case name
  when "google_oauth2" then "youtube"
  when "tiktok"        then "tiktok"
  else "auth"
  end

  path =
    if segment == "auth"
      "/#{locale}/api/#{ENV.fetch("AUTH_VERSION", "v1")}/auth/failure"
    else
      "/#{locale}/api/#{ENV.fetch("AUTH_VERSION", "v1")}/integrations/#{segment}/failure"
    end

  Rack::Response.new([], 302, "Location" => path).finish
end
