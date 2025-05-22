ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

class AuthServiceKarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'auth_service'
    config.kafka = {
      'bootstrap.servers': 'localhost:29092',
      'socket.keepalive.enable': true,
      'security.protocol': 'plaintext',
      'message.send.max.retries': 3
    }
    config.concurrency = 2
  end

  consumer_groups.draw do
    consumer_group :auth_service_group do
      topic :auth_service_get_user do
        consumer UserDataRequestConsumer
      end

      topic :minecraft_registration_requests do
        consumer MinecraftRegistrationConsumer
      end

      topic :user_login_events do
        consumer UserLoginConsumer
      end

      topic :two_factor_requests do
        consumer TwoFactorConsumer
      end

      topic :auth_service_set_about_me do
        consumer SetAboutMeConsumer
      end
    end
  end
end
