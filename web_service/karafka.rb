ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']

require ::File.expand_path('../config/environment', __FILE__)

Rails.application.eager_load!

class WebServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'web_service'
    config.kafka = {
      'bootstrap.servers': 'localhost:29092',
      'socket.keepalive.enable': true,
      'security.protocol': 'plaintext',
      'message.send.max.retries': 3
    }
    config.concurrency = 2
  end

  consumer_groups.draw do
    consumer_group :web_service_group do
      topic :user_updates do
        consumer UserUpdatesConsumer
      end
    end
  end
end
