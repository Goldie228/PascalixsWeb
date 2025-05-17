ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!


class MailerServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'mailer_service'
    config.kafka = {
      'bootstrap.servers': 'kafka:9092',
      'socket.keepalive.enable': true,
      'security.protocol': 'plaintext',
      'message.send.max.retries': 3
    }
    config.concurrency = 2
  end

  consumer_groups.draw do
    consumer_group :mailer_service_group do
      topic :email_request do
        consumer EmailConsumer
      end
    end
  end
end
