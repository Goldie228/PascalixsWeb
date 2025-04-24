# frozen_string_literal: true

# Базовый класс для всех продюсеров в приложении
class ApplicationProducer
  class << self
    # Метод класса для отправки сообщения в Kafka
    # @param topic [String, Symbol] Название топика
    # @param payload [Hash] Данные для отправки
    # @return [Boolean] Результат отправки
    def call(topic:, payload:)
      new.call(topic, payload)
    end
  end

  # Отправляет сообщение в Kafka
  # @param topic [String, Symbol] Название топика
  # @param payload [Hash] Данные для отправки
  # @return [Boolean] Результат отправки
  def call(topic, payload)
    begin
      Karafka.producer.produce_sync(
        topic: topic.to_s,
        payload: payload.is_a?(String) ? payload : payload.to_json
      )
      true
    rescue => e
      Rails.logger.error("Error producing message to #{topic}: #{e.message}")
      false
    end
  end
end 