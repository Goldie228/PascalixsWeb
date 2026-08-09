require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("Тесты запрещены в production-режиме!") if Rails.env.production?
require 'rspec/rails'

# Подключаем все файлы из spec/support/
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

begin
  if defined?(ActiveRecord)
    ActiveRecord::Migration.maintain_test_schema!
  end
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  if defined?(ActiveRecord)
    config.fixture_paths = [
      Rails.root.join('spec/fixtures')
    ]

    # Используем транзакции для изоляции тестов от БД
    config.use_transactional_fixtures = true
  end

  # Автоматически определяем тип спека по расположению файла
  config.infer_spec_type_from_file_location!

  # Фильтруем Rails-гемы из стек-трейсов
  config.filter_rails_from_backtrace!

  # FactoryBot: доступны методы create, build, build_stubbed и т.д.
  config.include FactoryBot::Syntax::Methods
end

# Shoulda::Matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# WebMock: блокируем внешние запросы, разрешаем localhost
WebMock.disable_net_connect!(allow_localhost: true)

# VCR: запись/воспроизведение HTTP-кассет
require 'vcr'
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
end
