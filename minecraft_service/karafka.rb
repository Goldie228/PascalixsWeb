ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class AuthServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'minecraft_service'
    config.kafka = {
      'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', 'localhost:29092'),
      'socket.keepalive.enable': true,
      'security.protocol': 'plaintext',
      'message.send.max.retries': 3
    }
    config.concurrency = 2
  end

  consumer_groups.draw do
    consumer_group :minecraft_service_group do
      topic :minecraft_service_get_roles do
        consumer RolesConsumer
      end

      topic :change_password_mc do
        consumer ChangePasswordMcConsumer
      end

      topic :change_pass_status do
        consumer ChangePassStatusConsumer
      end
    end
  end
end
