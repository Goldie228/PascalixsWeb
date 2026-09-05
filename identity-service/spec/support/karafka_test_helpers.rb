# Хелперы для тестирования Karafka-потребителей
module KarafkaTestHelpers
  # Создаёт мок Karafka-сообщения с заданным полезным нагрузкой
  def build_karafka_message(payload, topic: "test_topic", partition: 0, offset: 0, id: "msg-#{SecureRandom.hex(4)}")
    double(
      "Karafka::Messages::Message",
      payload: payload,
      topic: topic,
      partition: partition,
      offset: offset,
      id: id,
      raw_payload: payload.is_a?(String) ? payload : payload.to_json,
      metadata: double("metadata", topic: topic, partition: partition, offset: offset)
    )
  end

  # Создаёт мок экземпляра потребителя с заданными сообщениями
  def build_consumer(consumer_class, messages)
    consumer = consumer_class.new
    allow(consumer).to receive(:messages).and_return(messages)
    consumer
  end
end

RSpec.configure do |config|
  config.include KarafkaTestHelpers, type: :consumer
end
