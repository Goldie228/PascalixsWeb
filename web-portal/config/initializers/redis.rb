# Redis configuration with connection pool
# DB 1 — web-portal (web-portal)

redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')

REDIS_CLIENT = Redis.new(
  url: redis_url,
  reconnect_attempts: 3,
  timeout: 5
)

# Verify connection
begin
  REDIS_CLIENT.ping
  Rails.logger.info "Redis connected successfully (db: 1)"
rescue => e
  Rails.logger.error "Redis connection failed: #{e.message}"
  REDIS_CLIENT = nil
end
