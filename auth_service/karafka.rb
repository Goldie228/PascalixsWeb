class KarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'auth_service'
    
    config.kafka = {
      'bootstrap.servers': 'localhost:29092',
      'socket.keepalive.enable': true,
      'security.protocol': 'plaintext',
      'message.send.max.retries': 3
    }
    
    config.concurrency = 2
  end
end


# В auth_service мы создаем топики, но не потребляем их
# Другие сервисы будут подписываться на эти топики
Karafka::App.routes.draw do
  # Для обработки входящих событий от web_service, если потребуется
  topic :web_events do
    consumer WebEventsConsumer
  end
end