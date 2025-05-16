class CodeValidityJob < ApplicationJob
  include SuckerPunch::Job

  def perform
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))

    redis.subscribe("code_validity_updates") do |on|
      on.message do |_channel, message|
        begin
          data = JSON.parse(message)
          user_id = data["user_id"]
          valid = data["valid"]

          ActionCable.server.broadcast("code_validation_status_#{user_id}", {
            success: valid
          })

        rescue JSON::ParserError => e
          Rails.logger.error("Ошибка парсинга: #{e.message}. Сообщение: #{message}")
        end
      end
    end
  rescue => e
    Rails.logger.error("Ошибка в CodeValidityJob: #{e.message}")
    retry
  end
end
