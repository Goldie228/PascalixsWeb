ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class AuthServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'minecraft_service'
    config.kafka = {
      'bootstrap.servers': 'localhost:29092',
      'socket.keepalive.enable': true,
      'security.protocol': 'plaintext',
      'message.send.max.retries': 3
    }
    config.concurrency = 2
  end
end
