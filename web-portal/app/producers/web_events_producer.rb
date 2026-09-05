# frozen_string_literal: true

# Продюсер для отправки событий от веб-сервиса
class WebEventsProducer < ApplicationProducer
  TOPIC = 'web_events'.freeze
  
  class << self
    # Отправляет событие о просмотре страницы
    # @param user_id [String, Integer] ID пользователя, может быть nil для неавторизованных пользователей
    # @param page_path [String] Путь к странице
    # @param referrer [String] Страница, с которой пришел пользователь
    # @return [Boolean] Результат отправки
    def page_viewed(user_id, page_path, referrer)
      payload = {
        event_type: 'page_viewed',
        user_id: user_id,
        page_path: page_path,
        referrer: referrer,
        timestamp: Time.now.to_i
      }
      
      call(topic: TOPIC, payload: payload)
    end

    # Отправляет событие о действии пользователя
    # @param user_id [String, Integer] ID пользователя, может быть nil для неавторизованных пользователей
    # @param action_type [String] Тип действия
    # @param details [Hash] Дополнительные данные
    # @return [Boolean] Результат отправки
    def user_action(user_id, action_type, details)
      payload = {
        event_type: 'user_action',
        user_id: user_id,
        action_type: action_type,
        details: details,
        timestamp: Time.now.to_i
      }
      
      call(topic: TOPIC, payload: payload)
    end

    # Отправляет событие о возникновении ошибки
    # @param user_id [String, Integer] ID пользователя, может быть nil для неавторизованных пользователей
    # @param error_type [String] Тип ошибки
    # @param error_message [String] Сообщение об ошибке
    # @param page_path [String] Путь к странице, на которой произошла ошибка
    # @return [Boolean] Результат отправки
    def error_occurred(user_id, error_type, error_message, page_path)
      payload = {
        event_type: 'error_occurred',
        user_id: user_id,
        error_type: error_type,
        error_message: error_message,
        page_path: page_path,
        timestamp: Time.now.to_i
      }
      
      call(topic: TOPIC, payload: payload)
    end

    # Отправляет метрику производительности
    # @param user_id [String, Integer] ID пользователя, может быть nil для неавторизованных пользователей
    # @param metric_name [String] Название метрики
    # @param value [Float] Значение метрики
    # @param page_path [String] Путь к странице
    # @return [Boolean] Результат отправки
    def performance_metric(user_id, metric_name, value, page_path)
      payload = {
        event_type: 'performance_metric',
        user_id: user_id,
        metric_name: metric_name,
        value: value,
        page_path: page_path,
        timestamp: Time.now.to_i
      }
      
      call(topic: TOPIC, payload: payload)
    end
  end
end 