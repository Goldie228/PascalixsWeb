# Конфигурация Kafka для использования в приложении
# Это позволит использовать Karafka.producer напрямую из контроллеров и моделей

# Убедимся, что Karafka настроена
Karafka.monitor.subscribe('error.occurred') do |event|
  Rails.logger.error "Kafka error: #{event[:error]}"
end

# Используем уже настроенный продюсер из karafka.rb
# Глобальная настройка для доступа к producer'у Kafka из всего приложения
Rails.application.config.after_initialize do
  Rails.application.config.kafka_producer = Karafka.producer
end 