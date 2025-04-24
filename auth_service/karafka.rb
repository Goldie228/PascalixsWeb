Karafka::App.setup do |config|
  # Основные настройки приложения
  config.client_id = 'auth_service'
  
  # Настройки подключения к Kafka (параметры rdkafka)
  config.kafka = {
    'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', '127.0.0.1:9092'),
    'group.id': "auth_service_#{Rails.env}"
  }

  config.concurrency = 2
end

# В auth_service мы создаем топики, но не потребляем их
# Другие сервисы будут подписываться на эти топики
Karafka::App.routes.draw do
  # Для обработки входящих событий от web_service, если потребуется
  topic :web_events do
    consumer WebEventsConsumer
  end
end