# frozen_string_literal: true

# ApplicationProducer provides a shared Kafka producer for game-service.
# All consumers and workers should use this for sending messages to Kafka topics.
class ApplicationProducer
  class << self
    def produce_async(topic:, payload:, key: nil)
      producer.produce_async(
        topic: topic,
        payload: payload.is_a?(String) ? payload : payload.to_json,
        key: key
      )
    end

    def produce_sync(topic:, payload:, key: nil)
      producer.produce_sync(
        topic: topic,
        payload: payload.is_a?(String) ? payload : payload.to_json,
        key: key
      )
    end

    private

    def producer
      @producer ||= WaterDrop::Producer.new do |config|
        config.deliver = true
        config.kafka = {
          'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', 'localhost:29092'),
          'compression.codec': 'gzip',
          'compression.level': 6,
          'enable.idempotence': true
        }
      end
    end
  end
end
