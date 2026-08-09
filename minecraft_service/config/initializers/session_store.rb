Rails.application.config.session_store :redis_session_store,
  key: "_minecraft_service_session",
  redis: {
    client: REDIS_CLIENT,
    key_prefix: "session:",
    ttl: 120.minutes
  }
