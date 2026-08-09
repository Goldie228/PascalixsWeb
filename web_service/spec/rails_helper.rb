require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort("Rails работает в production режиме!") if Rails.env.production?

require 'rspec/rails'
require 'webmock/rspec'
require 'vcr'

# Автозагрузка support-файлов
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Проверка миграций перед запуском тестов
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

  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

WebMock.disable_net_connect!(allow_localhost: true)

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join('spec/fixtures/vcr_cassettes')
  config.hook_into :webmock
  config.ignore_localhost = true
  config.default_cassette_options = { record: :once }
  config.configure_rspec_metadata!
end
