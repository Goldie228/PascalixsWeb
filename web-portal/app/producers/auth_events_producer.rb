# frozen_string_literal: true

# Продюсер для отправки событий, связанных с аутентификацией
class AuthEventsProducer < ApplicationProducer
  TOPIC = 'auth_events'.freeze
  
  class << self
    # Отправляет сообщение о попытке входа в систему
    # @param email [String] Email пользователя
    # @param success [Boolean] Успешна ли попытка
    # @param ip_address [String] IP-адрес пользователя
    # @param user_agent [String] User-Agent браузера
    # @return [Boolean] Результат отправки
    def login_attempt(email, success, ip_address = nil, user_agent = nil)
      return false unless email.present?
      
      payload = {
        email: email,
        success: success,
        ip_address: ip_address,
        user_agent: user_agent,
        timestamp: Time.now.to_i,
        event_type: 'login_attempt'
      }
      
      call(topic: TOPIC, payload: payload)
    end
    
    # Отправляет сообщение о попытке выхода из системы
    # @param user_id [String, Integer] ID пользователя
    # @param success [Boolean] Успешна ли попытка
    # @param ip_address [String] IP-адрес пользователя
    # @return [Boolean] Результат отправки
    def logout_attempt(user_id, success, ip_address = nil)
      return false unless user_id.present?
      
      payload = {
        user_id: user_id,
        success: success,
        ip_address: ip_address,
        timestamp: Time.now.to_i,
        event_type: 'logout_attempt'
      }
      
      call(topic: TOPIC, payload: payload)
    end
    
    # Отправляет сообщение о попытке входа через OAuth
    # @param provider [String] Провайдер OAuth (Discord, Google и т.д.)
    # @param user_id [String, Integer] ID пользователя (если уже есть)
    # @param success [Boolean] Успешна ли попытка
    # @param error [String] Сообщение об ошибке (если есть)
    # @return [Boolean] Результат отправки
    def oauth_attempt(provider, user_id = nil, success = true, error = nil)
      return false unless provider.present?
      
      payload = {
        provider: provider,
        user_id: user_id,
        success: success,
        error: error,
        timestamp: Time.now.to_i,
        event_type: 'oauth_attempt'
      }
      
      call(topic: TOPIC, payload: payload)
    end
    
    # Отправляет сообщение о смене пароля
    # @param user_id [String, Integer] ID пользователя
    # @param success [Boolean] Успешна ли смена
    # @param forced [Boolean] Принудительная ли смена (например, по сбросу)
    # @return [Boolean] Результат отправки
    def password_change(user_id, success, forced = false)
      return false unless user_id.present?
      
      payload = {
        user_id: user_id,
        success: success,
        forced: forced,
        timestamp: Time.now.to_i,
        event_type: 'password_change'
      }
      
      call(topic: TOPIC, payload: payload)
    end
  end
end 