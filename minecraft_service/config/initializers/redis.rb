require 'uri'

redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379')
uri = URI.parse(redis_url)

REDIS_CLIENT = Redis.new(
  host: uri.host,
  port: uri.port,
  db: 0,
  password: uri.password,
  ssl: false
)
