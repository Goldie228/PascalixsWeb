redis_host = Rails.env.production? ? "redis" : "localhost"

Rails.application.config.session_store :redis_session_store,
  key: "_pascalixs_session",
  secure: true,
  same_site: :none,
  domain: :all,
  tld_length: 2,
  serializer: :json,
  httponly: true,
  redis: {
    client: REDIS_CLIENT,
    host: redis_host,
    port: 6379,
    db: 0,
    key_prefix: "session:",
    expire_after: 1.week
  }