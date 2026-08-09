require "spec_helper"

# Загружаем переменные окружения из .env файла родительской директории
require 'dotenv'
Dotenv.load(File.expand_path('../../.env', __dir__))

# Задаём тестовые значения для OAuth провайдеров
ENV["DISCORD_CLIENT_ID"] ||= "test_discord_client_id"
ENV["DISCORD_CLIENT_SECRET"] ||= "test_discord_client_secret"
ENV["GOOGLE_CLIENT_ID"] ||= "test_google_client_id"
ENV["GOOGLE_CLIENT_SECRET"] ||= "test_google_client_secret"

ENV["RAILS_ENV"] ||= "test"
# Redis для session store в тестах (порт 6379)
ENV["REDIS_URL"] = "redis://localhost:6379" if ENV["REDIS_URL"]&.include?("6380") || ENV["REDIS_URL"].nil?
require_relative "../config/environment"
# Прерываем запуск в production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "factory_bot_rails"
require "shoulda/matchers"
require "webmock/rspec"
require "vcr"
require "faker"
require "database_cleaner/active_record"

# Подключаем все файлы из spec/support/ (кастомные матчеры, хелперы, и т.д.)
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Проверяем и применяем миграции перед запуском тестов
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  # Если миграции не применены — загружаем схему напрямую
  ActiveRecord::Tasks::DatabaseTasks.load_schema_current(:ruby, File.expand_path("../db/schema.rb", __dir__))
end

# Заглушки для внешних продюсеров (Kafka), которые недоступны в тестах
# Важно: эти классы определяются ПОСЛЕ config/environment, чтобы Zeitwerk сначала загрузил реальные классы
unless defined?(AuthEventsProducer)
  class AuthEventsProducer
    def self.user_registered(*args); end
    def self.user_logged_in(*args); end
    def self.user_logged_out(*args); end
    def self.authentication_successful(*args); end
    def self.authentication_failed(*args); end
  end
end

# Базовый URL для генерации ссылок в тестах
Rails.application.routes.default_url_options[:host] = 'localhost:3000'

RSpec.configure do |config|
  config.example_status_persistence_file_path = "spec/examples.txt"
  # Подключаем методы FactoryBot (create, build, ...) без префикса
  config.include FactoryBot::Syntax::Methods

  # Разрешаем localhost в request specs для обхода HostAuthorization
  config.before(:each, type: :request) do
    host! "localhost" unless request.respond_to?(:host) && request.host.present?
  end

  # Пути к фикстурам (можно удалить, если не используете ActiveRecord fixtures)
  config.fixture_paths = [Rails.root.join("spec/fixtures")]

  # Отключаем встроенные транзакции — используем DatabaseCleaner вместо этого
  config.use_transactional_fixtures = false

  # DatabaseCleaner: :transaction быстрее :truncation
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  # Очередь задач — тестовый адаптер
  config.before(:each) do
    ActiveJob::Base.queue_adapter = :test
  end

  # Автоматическое определение типа теста по расположению файла
  # (get/post в контроллерах, и т.д.)
  # Отключить: удалить строку ниже и добавить type: :controller в describe
  # Подробнее: https://rspec.info/features/6-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Фильтруем Rails-стек из отчёта об ошибках
  config.filter_rails_from_backtrace!
end

# Shoulda::Matchers — однострочные тесты для моделей
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# WebMock — блокируем реальные HTTP-запросы в тестах
WebMock.disable_net_connect!(allow_localhost: true)

# VCR — записывает и воспроизводит HTTP-запросы
VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("spec/fixtures/vcr_cassettes")
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  # Разрешаем реальные HTTP-запросы к localhost для system tests
  config.ignore_hosts "127.0.0.1", "localhost"
end
