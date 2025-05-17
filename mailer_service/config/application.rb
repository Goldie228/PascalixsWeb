require "rails"
require "action_mailer/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

module MailerService
  class Application < Rails::Application
    config.load_defaults 7.2

    config.api_only = true
  end
end
