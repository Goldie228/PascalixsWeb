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
          bootstrap_servers: ENV.fetch('KAFKA_BROKERS', 'localhost:29092'),
          compression_codec: 'gzip',
          compression_level: 6,
          enable_idempotence: true
        }
      end
    end
  end
end
