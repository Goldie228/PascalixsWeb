redis_host = Rails.env.production? ? 'redis' : 'localhost'

Rails.application.config.session_store :redis_session_store,
  key: '_auth_service_session',
  redis: {
    client: REDIS_CLIENT,
    host: redis_host,
    port: 6379,
    db: 0,
    expire_after: 120.minutes,
    key_prefix: 'session:',
    local: [:user_id]
  }
