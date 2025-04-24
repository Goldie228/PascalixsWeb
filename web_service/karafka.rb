ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']

require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

if Rails.env.development?
  stdout_logger = Logger.new($stdout)
  stdout_logger.formatter = Rails.logger.formatter
  Rails.logger = ActiveSupport::TaggedLogging.new(stdout_logger)
end

class KarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'web_service'
    config.concurrency = 5
    config.max_wait_time = 1_000
    config.kafka = {
      'bootstrap.servers': 'kafka:9092',
      'allow.auto.create.topics': true
    }
  end

  Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)

  routes.draw do
    consumer_group :auth_consumers do
      topic :auth_events do
        consumer AuthEventsConsumer
      end
      
      topic :user_events do
        consumer UserEventsConsumer
      end
      
      topic :user_login_events do
        consumer UserLoginConsumer
      end
      
      topic :user_registration_events do
        consumer UserRegistrationConsumer
      end
      
      topic :user_logout_events do
        consumer UserLogoutConsumer
      end
    end
  end
end

Karafka.monitor.subscribe('app.initialized') do
end
