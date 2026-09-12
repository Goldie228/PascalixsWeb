# Redis configuration with connection pool
# DB 2 — game-service (game-service)

redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/2')

REDIS_CLIENT = Redis.new(
  url: redis_url,
  reconnect_attempts: 3,
  timeout: 5
)

# Verify connection
begin
  REDIS_CLIENT.ping
  Rails.logger.info "Redis connected successfully (db: 2)"
rescue => e
  Rails.logger.error "Redis connection failed: #{e.message}"
  REDIS_CLIENT = nil
end
