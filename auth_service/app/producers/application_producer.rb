class ApplicationProducer
  class << self
    def call(topic:, payload:)
      producer.produce_sync(
        topic: topic, 
        payload: payload.to_json
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