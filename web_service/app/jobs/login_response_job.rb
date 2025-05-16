require "timeout"

class LoginResponseJob < ApplicationJob
  queue_as :default

  def perform(correlation_id)
    response = wait_for_response(correlation_id)

    unless response.nil?
      Rails.logger.info "LoginResponseJob: Получен ответ: #{response}"
      broadcast_response(correlation_id, response)
    else
      Rails.logger.error "LoginResponseJob: Таймаут ожидания ответа для correlation_id: #{correlation_id}"
    end
  end

  private

  def wait_for_response(correlation_id)
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))

    channel = "auth_responses:#{correlation_id}"
    message = nil

    begin
      Timeout.timeout(15) do
        redis.subscribe(channel) do |on|
          on.message do |chan, msg|
            message = msg
            redis.unsubscribe(chan)
          end
        end
      end
    rescue Timeout::Error
      Rails.logger.error "Timeout waiting for message on #{channel}"
    ensure
      redis.close
    end

    message ? JSON.parse(message) : nil
  end

  def broadcast_response(correlation_id, response)
    # Приводим ключи ответа к camelCase, если нужно
    message = { response: response.deep_transform_keys { |k| k.to_s.camelize(:lower) } }
    Rails.logger.info "LoginResponseJob: Broadcast message: #{message} для correlation_id: #{correlation_id}"
    ActionCable.server.broadcast("login_channel_#{correlation_id}", message)
  end
end
