require "click_house"

ClickHouse.config do |config|
  config.url      = ENV.fetch("CLICKHOUSE_HOST", "http://localhost:8123")
  config.username = ENV["CLICKHOUSE_USER"]       # ← исправлено
  config.password = ENV["CLICKHOUSE_PASSWORD"]
  config.database = "default"
  config.timeout  = 60
end
