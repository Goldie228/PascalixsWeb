# Redis configuration with connection pool
# DB 1 — web_service (web-portal)

redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
rails_threads = ENV.fetch('RAILS_MAX_THREADS', 5).to_i

REDIS_CLIENT = Redis.new(
  url: redis_url,
  pool: { size: rails_threads, timeout: 1000 },
  reconnect_attempts: 3,
  socket_timeout: 5
)

# Verify connection
begin
  REDIS_CLIENT.ping
  Rails.logger.info "Redis connected successfully (db: 1)"
rescue => e
  Rails.logger.error "Redis connection failed: #{e.message}"
  REDIS_CLIENT = nil
end
