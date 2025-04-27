class WebEventsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = JSON.parse(message.payload)
      log_message(payload)
      process_message(payload)
    end
  end

  private

  def process_message(payload)
    event_type = payload['event_type']

    # Обработка событий с использованием дедупликации
    with_deduplication("web_event:#{payload['user_id']}:#{event_type}:#{payload['timestamp']}") do
      case event_type
      when 'page_viewed'
        handle_page_viewed(payload)
      when 'user_action'
        handle_user_action(payload)
      when 'error_occurred'
        handle_error_occurred(payload)
      when 'performance_metric'
        handle_performance_metric(payload)
      else
        Rails.logger.info "Неизвестный тип события: #{event_type}"
      end
    end
  end

  def handle_page_viewed(payload)
    Rails.logger.info "Просмотр страницы: пользователь #{payload['user_id']} просмотрел #{payload['page_path']}"
  end

  def handle_user_action(payload)
    Rails.logger.info "Действие пользователя: пользователь #{payload['user_id']} выполнил действие #{payload['action_type']}"
    
    # Обработка конкретных действий пользователя
    case payload['action_type']
    when 'login_attempt'
      Rails.logger.info "Попытка входа: #{payload['details']}"
    when 'profile_view'
      Rails.logger.info "Просмотр профиля: #{payload['details']}"
    when 'settings_changed'
      Rails.logger.info "Изменение настроек: #{payload['details']}"
    end
  end

  def handle_error_occurred(payload)
    Rails.logger.error "Ошибка во фронтенде: тип=#{payload['error_type']}, сообщение=#{payload['error_message']}, пользователь=#{payload['user_id']}, страница=#{payload['page_path']}"
  end

  def handle_performance_metric(payload)
    Rails.logger.info "Метрика производительности: метрика=#{payload['metric_name']}, значение=#{payload['value']}, пользователь=#{payload['user_id']}, страница=#{payload['page_path']}"
  end
  
  def log_message(payload)
    Rails.logger.debug "Получено событие от web_service: #{payload.inspect}"
  end
end 