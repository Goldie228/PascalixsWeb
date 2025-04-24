class ApplicationConsumer < Karafka::BaseConsumer
  def consume
    raise NotImplementedError, "#{self.class} must implement consume method"
  end

  protected

  def find_user(user_id)
    User.find_by(id: user_id)
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