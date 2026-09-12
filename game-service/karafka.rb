ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class GameServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'game-service'
    config.kafka = {
      :'bootstrap.servers' => ENV.fetch('KAFKA_BROKERS', 'localhost:29092'),
      :'socket.keepalive.enable' => true,
      :'message.send.max.retries' => 3,
      :'retry.backoff.ms' => 1000
    }
    config.concurrency = 2
    config.strict_topics_namespacing = false
  end

  # Exactly-once semantics for producer
  begin
    if defined?(Karafka::Producers) && defined?(Karafka::Producers::Producer)
      Karafka::Producers::Producer.setup do |producer_config|
        producer_config.kafka = {
          :'acks' => 'all',
          :'enable.idempotence' => true,
          :'max.in.flight.requests.per.connection' => 5
        }
      end
    end
  rescue NameError, NoMethodError
    # Producer setup not available in this Karafka version
  end

  consumer_groups.draw do
    consumer_group :game_service_group do
      # Role requests
      topic 'game.player.roles_requested' do
        consumer RolesConsumer
      end
    end
  end
end
