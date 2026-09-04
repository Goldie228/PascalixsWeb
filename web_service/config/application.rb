require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WebService
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])
    config.action_dispatch.cookies_serializer = :json

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.action_controller.allow_forgery_protection = false

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins(
          [
            'https://pascalixs.fun',
            'https://auth.pascalixs.fun',
            ENV['WEB_SERVICE_URL'],
            ENV['AUTH_SERVICE_URL']
          ].compact
        )
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          credentials: true,  # Разрешить передачу кук
          expose: ['Set-Cookie']  # Разрешить чтение кук в клиенте
      end
    end

    # Add rate limiting middleware after CORS
    config.middleware.insert_after Rack::Cors, RateLimitingMiddleware
  end
end
