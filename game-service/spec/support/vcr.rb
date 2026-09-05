# Конфигурация VCR
VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join('spec', 'fixtures', 'vcr_cassettes')
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
end
