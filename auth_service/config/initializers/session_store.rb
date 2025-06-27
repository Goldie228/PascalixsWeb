redis_host = Rails.env.production? ? "redis" : "localhost"

Rails.application.config.session_store :redis_session_store,
  key: "_auth_service_session",
  same_site: :lax,
  secure:    Rails.env.production?,
  httponly:  true,
  expire_after: 2.hours,
  redis: {
    client:     REDIS_CLIENT,
    host:       redis_host,
    port:       6379,
    db:         0,
    key_prefix: "session:",
    ttl:        120.minutes
  }
