class User < ApplicationRecord
  # В web_service нам нужна минимальная модель только для хранения данных
  # Аутентификация и валидация будут в auth_service
  
  # Связи
  has_one :minecraft_account, dependent: :destroy

  # Виртуальные атрибуты для упрощения работы с данными от auth_service
  attr_accessor :is_registered

  # Методы для совместимости
  def email
    read_attribute(:email)
  end

  def username
    read_attribute(:username)
  end

  # Публикация событий для других сервисов
  def publish_user_updated
    payload = {
      id: id,
      email: email,
      username: username,
      updated_at: updated_at.iso8601
    }.to_json

    Rails.application.config.kafka_producer.produce_sync(
      topic: 'user_update_events',
      payload: payload
    )
  rescue => e
    Rails.logger.error("Failed to publish user update event: #{e.message}")
  end
end 