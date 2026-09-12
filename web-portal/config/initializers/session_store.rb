auth_url = ENV["IDENTITY_SERVICE_URL"].to_s.strip
web_url  = ENV["WEB_PORTAL_URL"].to_s.strip

local_mode = [auth_url, web_url].all? { |u| u =~ %r{\Ahttps?://(localhost|127\.0\.0\.1)(:\d+)?}i }

session_options = {
  key: "_pascalixs_session",
  serializer: :json,
  httponly: true,
  same_site: local_mode ? :lax : :none,
  secure: !local_mode,
  domain: local_mode ? nil : ".pascalixs.fun"
}

# Only configure Redis session store if Redis client is available
if defined?(REDIS_CLIENT) && REDIS_CLIENT
  session_options[:redis] = {
    client: REDIS_CLIENT,
    key_prefix: "session:",
    expire_after: 1.week
  }
end

Rails.application.config.session_store(:redis_session_store, **session_options)
