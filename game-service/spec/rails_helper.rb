require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
ENV['WEB_PORTAL_URL'] ||= 'http://localhost:3000'
ENV['INTER_SERVICE_API_KEY'] ||= 'test-api-key'
require_relative '../config/environment'
# Запрещаем запуск в production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  config.use_transactional_fixtures = true

  # Автоматическое определение типа спецификации по расположению файла
  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!

  # FactoryBot: методы create, build и т.д.
  config.include FactoryBot::Syntax::Methods
end

# Конфигурация Shoulda::Matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Конфигурация WebMock
WebMock.disable_net_connect!(allow_localhost: true)

# Конфигурация VCR
VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join('spec', 'fixtures', 'vcr_cassettes')
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
end
