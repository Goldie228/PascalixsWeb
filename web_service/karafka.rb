
ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']


require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class WebServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'web_service'
    config.kafka = {
      'bootstrap.servers': 'localhost:29092',
      'security.protocol': 'PLAINTEXT',
      'socket.keepalive.enable': true,
      'message.send.max.retries': 3
    }
    config.concurrency = 2
  end
end
