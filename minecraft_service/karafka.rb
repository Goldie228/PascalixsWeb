ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class MinecraftServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'minecraft_service'
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

  consumer_groups.draw do
    consumer_group :game_service_group do
      topic 'game.player.roles_requested' do
        consumer RolesConsumer
      end

      topic 'game.player.password_changed' do
        consumer ChangePasswordMcConsumer
      end

      topic 'game.player.status_changed' do
        consumer ChangePassStatusConsumer
      end
    end
  end
end
