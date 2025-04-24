class ApplicationProducer < Karafka::BaseProducer
  def self.call(topic:, payload:)
    new.call(topic, payload)
  end

  def call(topic, payload)
    producer.produce_async(
      topic: topic,
      payload: payload.to_json
    )
  end
end 