auth_url = ENV["AUTH_SERVICE_URL"].to_s.strip
web_url  = ENV["WEB_SERVICE_URL"].to_s.strip

local_mode = [auth_url, web_url].all? { |u| u =~ %r{\Ahttps?://(localhost|127\.0\.0\.1)(:\d+)?}i }

Rails.application.config.session_store :redis_session_store,
  key: "_pascalixs_session",
  serializer: :json,
  httponly: true,
  same_site: local_mode ? :lax : :none,
  secure: !local_mode,
  domain: local_mode ? nil : ".pascalixs.fun",
  redis: {
    client: REDIS_CLIENT,
    key_prefix: "session:",
    expire_after: 1.week
  }
