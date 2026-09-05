require "rails"
require "action_mailer/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

module NotificationService
  class Application < Rails::Application
    config.load_defaults 7.2

    config.api_only = true

    # Add inter-service auth middleware before rate limiting (first in stack)
    config.middleware.insert_before 0, InterServiceAuth

    # Add rate limiting middleware
    config.middleware.insert_before 0, RateLimitingMiddleware
  end
end
