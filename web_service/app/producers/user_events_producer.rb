# frozen_string_literal: true

# Продюсер для отправки событий, связанных с пользователями
class UserEventsProducer < ApplicationProducer
  TOPIC = 'user_events'.freeze
  
  class << self
    # Отправляет сообщение о том, что пользователь успешно вошел в систему
    # @param user [Hash] Информация о пользователе
    # @return [Boolean] Результат отправки
    def user_logged_in(user)
      return false unless user && user[:id].present?
      
      payload = {
        user_id: user[:id],
        email: user[:email],
        timestamp: Time.now.to_i,
        event_type: 'user_logged_in'
      }
      
      call(topic: TOPIC, payload: payload)
    end
    
    # Отправляет сообщение о том, что пользователь вышел из системы
    # @param user_id [String, Integer] ID пользователя
    # @return [Boolean] Результат отправки
    def user_logged_out(user_id)
      return false unless user_id.present?
      
      payload = {
        user_id: user_id,
        timestamp: Time.now.to_i,
        event_type: 'user_logged_out'
      }
      
      call(topic: TOPIC, payload: payload)
    end
    
    # Отправляет сообщение о регистрации нового пользователя
    # @param user [Hash] Информация о пользователе
    # @return [Boolean] Результат отправки
    def user_registered(user)
      return false unless user && user[:id].present?
      
      payload = {
        user_id: user[:id],
        email: user[:email],
        registration_method: user[:registration_method] || 'email',
        timestamp: Time.now.to_i,
        event_type: 'user_registered'
      }
      
      call(topic: TOPIC, payload: payload)
    end
    
    # Отправляет сообщение об обновлении профиля пользователя
    # @param user_id [String, Integer] ID пользователя
    # @param changes [Hash] Измененные поля профиля
    # @return [Boolean] Результат отправки
    def profile_updated(user_id, changes)
      return false unless user_id.present? && changes.present?
      
      payload = {
        user_id: user_id,
        changes: changes,
        timestamp: Time.now.to_i,
        event_type: 'profile_updated'
      }
      
      call(topic: TOPIC, payload: payload)
    end
  end
end 