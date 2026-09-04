require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort("Rails работает в production режиме!") if Rails.env.production?

require 'rspec/rails'
require 'webmock/rspec'
require 'vcr'

# Автозагрузка support-файлов
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# web_service использует nulldb — миграции не проверяем

RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  config.use_transactional_fixtures = true

  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  # Современный User-Agent для обхода allow_browser versions: :modern
  config.before(:each, type: :request) do
    default_headers = { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @default_request_headers = default_headers
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with('_csrf_token').and_return('test-csrf-token')
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:_csrf_token).and_return('test-csrf-token')
    # Заглушаем CSRF токен чтобы избежать ошибок кодирования base64
    allow_any_instance_of(ActionController::Base).to receive(:real_csrf_token).and_return('test-csrf-token')
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:time_zone).and_return('UTC')
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:user_id).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:two_factor_passed).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:alert).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:notice).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:locale).and_return('en')
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:login_correlation_id).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:password_reset_pending).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:email_login).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:sended_email).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:login_mode).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:send_email).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:new_email).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:password_reset_key).and_return(nil)
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with('flash').and_return({})
    allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:flash).and_return({})
  end

  # Заглушаем загрузку flash из session чтобы избежать ошибок при nil/некорректном формате
  config.before(:each) do
    allow(ActionDispatch::Flash::FlashHash).to receive(:from_session_value) do |value|
      case value
      when Hash
        flashes = value["flashes"] || {}
        if discard = value["discard"]
          flashes.except!(*discard)
        end
        ActionDispatch::Flash::FlashHash.new(flashes, flashes.keys)
      else
        ActionDispatch::Flash::FlashHash.new
      end
    end
  end
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
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = { record: :once }
  config.ignore_request { |request| request.uri.include?('auth-service.test') || request.uri.include?('auth.test') }
  config.configure_rspec_metadata!
end
