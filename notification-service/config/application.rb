require "rails"
require "action_mailer/railtie"
require "action_cable/engine"
require "active_record/railtie"

# Require middleware and services
require_relative "../app/middleware/inter_service_auth"
require_relative "../app/middleware/rate_limiting_middleware"

Bundler.require(*Rails.groups)

module NotificationService
  class Application < Rails::Application
    config.load_defaults 7.2
    config.api_only = true

    config.autoload_paths << Rails.root.join('app/consumers')
    config.autoload_paths << Rails.root.join('app/middleware')
    config.autoload_paths << Rails.root.join('app/services')

    # Add inter-service auth middleware before rate limiting (first in stack)
    config.middleware.insert_before 0, InterServiceAuth

    # Add rate limiting middleware
    config.middleware.insert_before 0, RateLimitingMiddleware
  end
end
