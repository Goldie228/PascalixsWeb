ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class NotificationServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'notification-service'
    config.kafka = {
      'bootstrap.servers' => ENV.fetch('KAFKA_BROKERS', 'localhost:29092'),
      'socket.keepalive.enable' => true,
      'message.send.max.retries' => 3,
      'retry.backoff.ms' => 1000
    }
    config.concurrency = 2
  end

  # Exactly-once semantics for producer
  Karafka::Producer.setup do |producer_config|
    producer_config.kafka = {
      'acks' => 'all',
      'enable.idempotence' => true,
      'max.in.flight.requests.per.connection' => 5
    }
  end

  consumer_groups.draw do
    # ── Legacy topics (existing consumers) ──
    consumer_group :notification_service_group do
      topic 'notification.email.sent' do
        consumer EmailConsumer
      end

      topic 'notification.email.verified' do
        consumer SendCheckEmailConsumer
      end

      topic 'notification.password_reset.sent' do
        consumer SendPasswordResetEmailConsumer
      end
    end

    # ── New unified notification topics ──
    consumer_group :notification_service_group do
      topic 'notification.email' do
        consumer EmailNotificationConsumer
      end

      topic 'notification.push' do
        consumer PushNotificationConsumer
      end

      topic 'notification.template' do
        consumer TemplateNotificationConsumer
      end
    end
  end
end
