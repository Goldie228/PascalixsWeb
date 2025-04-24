# frozen_string_literal: true

# Консьюмер для обработки событий аутентификации от auth_service
class AuthEventsConsumer < ApplicationConsumer
  # Обрабатывает все входящие сообщения из темы auth_events
  def consume
    messages.each do |message|
      begin
        # Парсим JSON-сообщение
        payload = JSON.parse(message.payload)
        event_type = payload['event_type']
        
        # Обрабатываем событие в зависимости от типа
        case event_type
        when 'user_authenticated'
          handle_user_authenticated(payload)
        when 'user_registered'
          handle_user_registered(payload)
        when 'authentication_failed'
          handle_authentication_failed(payload)
        when 'user_session_expired'
          handle_user_session_expired(payload)
        when 'user_permissions_updated'
          handle_user_permissions_updated(payload)
        else
          # Логируем неизвестный тип события
          Rails.logger.warn("Unknown auth event type: #{event_type}")
        end
      rescue JSON::ParserError => e
        # Логируем ошибку парсинга сообщения
        Rails.logger.error("Invalid JSON in auth event: #{e.message}")
      rescue StandardError => e
        # Логируем общую ошибку обработки
        Rails.logger.error("Error processing auth event: #{e.message}")
      end
    end
  end
  
  private
  
  # Обрабатывает событие успешной аутентификации пользователя
  # @param payload [Hash] Данные события
  def handle_user_authenticated(payload)
    user_id = payload['user_id']
    Rails.logger.info("User authenticated: #{user_id}")
    
    # Здесь может быть дополнительная логика, например:
    # - обновление статуса пользователя в кэше
    # - обновление timestamp последнего входа
    # - отправка уведомления о входе в систему
  end
  
  # Обрабатывает событие регистрации нового пользователя
  # @param payload [Hash] Данные события
  def handle_user_registered(payload)
    user_id = payload['user_id']
    email = payload['email']
    Rails.logger.info("New user registered: #{user_id}, #{email}")
    
    # Здесь может быть дополнительная логика, например:
    # - создание профиля пользователя
    # - отправка приветственного email
    # - инициализация настроек по умолчанию
  end
  
  # Обрабатывает событие неудачной аутентификации
  # @param payload [Hash] Данные события
  def handle_authentication_failed(payload)
    email = payload['email']
    reason = payload['reason']
    ip_address = payload['ip_address']
    
    Rails.logger.warn("Authentication failed for #{email} from #{ip_address}: #{reason}")
    
    # Здесь может быть дополнительная логика, например:
    # - увеличение счетчика неудачных попыток
    # - временная блокировка IP-адреса при множественных неудачах
    # - отправка уведомления о подозрительной активности
  end
  
  # Обрабатывает событие истечения сессии пользователя
  # @param payload [Hash] Данные события
  def handle_user_session_expired(payload)
    user_id = payload['user_id']
    session_id = payload['session_id']
    
    Rails.logger.info("User session expired: #{user_id}, session: #{session_id}")
    
    # Здесь может быть дополнительная логика, например:
    # - инвалидация локальных кэшей сессии
    # - отправка уведомления пользователю
  end
  
  # Обрабатывает событие обновления прав доступа пользователя
  # @param payload [Hash] Данные события
  def handle_user_permissions_updated(payload)
    user_id = payload['user_id']
    permissions = payload['permissions']
    
    Rails.logger.info("User permissions updated: #{user_id}")
    
    # Здесь может быть дополнительная логика, например:
    # - обновление локального кэша прав пользователя
    # - перезагрузка активных сессий пользователя
    # - отправка уведомления об изменении прав
  end
end 