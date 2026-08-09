class ApplicationConsumer < Karafka::BaseConsumer
  MAX_RETRIES = 10

  def consume
    raise NotImplementedError, "#{self.class} must implement consume method"
  end

  def get_user_locale(user_id)
    locale = REDIS_CLIENT.hget("user:#{user_id}", "time_zone")

    # Если locale отсутствует или пустой, возвращаем значение по умолчанию
    locale && !locale.strip.empty? ? locale : "Moscow"
  end

  def produce_with_retries(topic, payload)
    retries = 0

    Rails.logger.info "Send..."

    loop do
      begin
        message = payload.to_json
        Karafka.producer.produce_async(
          topic: topic,
          payload: message
        )
        Rails.logger.info "Sended #{message}"
        break
      rescue => e
        if retries < MAX_RETRIES
          Rails.logger.error "Failed to produce to #{topic}: #{e.message}. Retrying... (Attempt #{retries + 1}/#{MAX_RETRIES})"
          retries += 1
        else
          Rails.logger.error "Failed to produce to #{topic} after #{MAX_RETRIES} attempts: #{e.message}"
          raise
        end
      end
    end
  end

  protected

  def find_user(user_id)
    User.find_by(id: user_id)
  end

  def log_event(event_name, payload)
    Rails.logger.info "[EVENT] #{event_name}: #{payload.to_json}"
  end
end
