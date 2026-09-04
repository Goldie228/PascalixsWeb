class ApplicationConsumer < Karafka::BaseConsumer
  MAX_RETRIES = 10

  def consume
    raise NotImplementedError, "#{self.class} must implement consume method"
  end

  # Парсинг payload: строка → Hash, уже Hash → возвращает как есть
  def parse_payload(raw)
    return raw if raw.is_a?(Hash)
    return nil if raw.nil? || raw.empty?

    JSON.parse(raw, symbolize_names: true)
  rescue JSON::ParserError => e
    Rails.logger.error "[#{self.class.name}] JSON parse error: #{e.message}"
    nil
  end

  # Валидация обязательных ключей
  def validate_required_keys(payload, required_keys)
    missing = required_keys - payload.keys
    if missing.any?
      Rails.logger.warn "[#{self.class.name}] Missing keys: #{missing.join(', ')}"
      return false
    end
    true
  end

  # Production с retry
  def produce_with_retries(topic, payload)
    retries = 0
    message = payload.is_a?(Hash) ? payload.to_json : payload

    loop do
      begin
        Karafka.producer.produce_async(topic: topic, payload: message)
        Rails.logger.info "[#{self.class.name}] Produced to #{topic}: #{message}"
        break
      rescue => e
        if retries < MAX_RETRIES
          Rails.logger.error "[#{self.class.name}] Failed to produce to #{topic}: #{e.message}. Retrying... (#{retries + 1}/#{MAX_RETRIES})"
          retries += 1
        else
          raise
        end
      end
    end
  end

  # Safe find user
  def find_user(user_id)
    User.find_by(id: user_id)
  end

  # Получение locale пользователя
  def get_user_locale(user_id)
    locale = REDIS_CLIENT&.hget("user:#{user_id}", "time_zone")
    locale && !locale.strip.empty? ? locale : "Moscow"
  end

  # Логирование событий
  def log_event(event_name, payload)
    Rails.logger.info "[EVENT] #{event_name}: #{payload.to_json}"
  end

  # Обработка ошибок
  def handle_error(error, context = {})
    context_str = context.map { |k, v| "#{k}=#{v}" }.join(', ')
    Rails.logger.error "[#{self.class.name}] Error: #{error.message} #{context_str}"
    Rails.logger.debug error.backtrace.first(10).join("\n")
  end

  protected

  # Safe update с валидацией
  def safe_update(record, attrs)
    if record.update(attrs)
      Rails.logger.info "[#{self.class.name}] Updated #{record.class.name} #{record.id}"
      true
    else
      Rails.logger.error "[#{self.class.name}] Validation failed for #{record.class.name} #{record.id}: #{record.errors.full_messages.join(', ')}"
      false
    end
  end
end
