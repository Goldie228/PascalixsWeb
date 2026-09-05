class ApplicationConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      process_message(message)
    end
  end

  private

  def process_message(message)
    payload = JSON.parse(message.payload)
    event_type = payload['event_type']
    
    case event_type
    when 'user_registered'
      handle_user_registered(payload)
    when 'user_logged_in'
      handle_user_logged_in(payload)
    when 'user_logged_out'
      handle_user_logged_out(payload)
    else
      Rails.logger.info "Unhandled event type: #{event_type}"
    end
  end

  def handle_user_registered(payload)
    Rails.logger.info "User registered: #{payload['user_id']}"
    # Здесь можно добавить логику обработки регистрации
  end

  def handle_user_logged_in(payload)
    Rails.logger.info "User logged in: #{payload['user_id']}"
    # Здесь можно добавить логику обработки входа
  end

  def handle_user_logged_out(payload)
    Rails.logger.info "User logged out: #{payload['user_id']}"
    # Здесь можно добавить логику обработки выхода
  end
  
  # Метод для предотвращения обработки дубликатов
  def with_deduplication(key, expires_in: 1.hour)
    # Формируем уникальный ключ для проверки дублирования
    deduplication_key = "deduplication:#{key}"
    
    # Проверяем, был ли такой ключ обработан ранее
    return false if Rails.cache.exist?(deduplication_key)
    
    # Если ключ не найден, записываем его и обрабатываем сообщение
    Rails.cache.write(deduplication_key, true, expires_in: expires_in)
    
    # Выполняем блок
    yield
    
    # Возвращаем true - сообщение обработано
    true
  end
  
  def log_event(event_name, payload)
    Rails.logger.info "[EVENT] #{event_name}: #{payload.to_json}"
  end
end
