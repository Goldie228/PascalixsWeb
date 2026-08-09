require "click_house"

ClickHouse.config do |config|
  host = ENV.fetch("CLICKHOUSE_HOST", "localhost")
  port = ENV.fetch("CLICKHOUSE_PORT", "8123")
  config.url      = "http://#{host}:#{port}"
  config.username = ENV["CLICKHOUSE_USER"]
  config.password = ENV["CLICKHOUSE_PASSWORD"]
  config.database = "default"
  config.timeout  = 60
end
