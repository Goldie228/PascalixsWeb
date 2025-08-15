require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AuthService
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Обеспечиваем правильную работу OmniAuth и сессий для API-based приложения
    
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use OmniAuth::Builder
    config.i18n.fallbacks = true
    
    # Добавляем поддержку для ActionDispatch::Flash для сообщений об ошибках
    config.middleware.use ActionDispatch::Flash

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.autoload_paths << Rails.root.join('app/consumers')
    config.action_dispatch.cookies_serializer = :json

    config.action_controller.allow_forgery_protection = false
    
    # Настройка CORS для взаимодействия с web_service
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins(
          'https://pascalixs.fun',
          'https://auth.pascalixs.fun',
          'http://localhost:3000',
          'http://localhost:3001',
          'http://127.0.0.1:3000',
          'http://127.0.0.1:3001',
          'http://[::1]:3000',
          'http://[::1]:3001'
        )
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          credentials: true,  # Разрешить передачу кук
          expose: ['Set-Cookie']  # Разрешить чтение кук в клиенте
      end
    end
  end
end
