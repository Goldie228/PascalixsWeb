class HealthController < ApplicationController
  skip_before_action :update_current_user, :set_locale, :redirect_to_default_locale, :set_timezone, :transfer_session_flash

  def check
    status = {
      status:    "healthy",
      timestamp: Time.now.iso8601,
      services:  {
        redis:        check_redis,
        kafka:        check_kafka,
        identity:     check_service(:identity),
        game:         check_service(:game),
        notification: check_service(:notification)
      }
    }

    all_healthy = status[:services].values.all? { |v| v == "ok" }
    render json: status, status: all_healthy ? 200 : 503
  end

  private

  def check_redis
    REDIS_CLIENT.ping == "PONG" ? "ok" : "error"
  rescue => e
    Rails.logger.warn "Redis health check failed: #{e.message}"
    "error"
  end

  def check_kafka
    # Kafka connectivity check via Karafka producer
    return "error" unless defined?(Karafka)

    begin
      Karafka.producer
      "ok"
    rescue => e
      Rails.logger.warn "Kafka health check failed: #{e.message}"
      "error"
    end
  end

  def check_service(service)
    result = GatewayService.new(timeout: 3).proxy(service, :get, "/health")
    result[:status] == 200 ? "ok" : "error"
  rescue => e
    Rails.logger.warn "#{service} health check failed: #{e.message}"
    "error"
  end
end
