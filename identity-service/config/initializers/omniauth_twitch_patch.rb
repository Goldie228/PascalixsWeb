require 'omniauth/strategies/oauth2'

module OmniAuth::Strategies
  class Twitch < OAuth2
    def callback_url
      full_host + script_name + callback_path
    end
  end
end
