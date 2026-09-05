ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class WebPortalKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'web-portal'
    config.kafka = {
      'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', 'localhost:29092'),
      'socket.keepalive.enable': true,
      'message.send.max.retries': 3,
      'retry.backoff.ms': 1000
    }
    config.concurrency = 2
  end

  # Exactly-once semantics for producer
  Karafka::Producer.setup do |producer_config|
    producer_config.kafka = {
      'acks': 'all',
      'enable.idempotence': true,
      'max.in.flight.requests.per.connection': 5
    }
  end
end
