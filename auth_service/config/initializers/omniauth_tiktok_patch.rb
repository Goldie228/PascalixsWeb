require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class TikTok < OmniAuth::Strategies::OAuth2
      option :name, 'tiktok'

      # v1-endpoints
      option :client_options, {
        site:          'https://open-api.tiktok.com',
        authorize_url: '/platform/oauth/connect',    # /platform/oauth/connect?client_key=...
        token_url:     '/oauth/access_token'         # POST /oauth/access_token
      }

      # Формируем authorize URL
      def authorize_params
        super.tap do |params|
          params[:client_key]   = params.delete(:client_id)
          params[:redirect_uri] = callback_url
          params[:response_type]= 'code'
          params[:scope]        = options[:scope] || 'user.info.basic'
        end
      end

      # Обмен кода на токен
      def token_params
        super.tap do |params|
          params[:client_key]    = options.client_id
          params[:client_secret] = options.client_secret
          params.delete(:client_id)
          params[:grant_type]    = 'authorization_code'
        end
      end

      # UID — это open_id, который вернёт TikTok
      uid { access_token.params['open_id'] }

      info do
        {
          nickname: raw_info.dig('data','nickname'),
          avatar:   raw_info.dig('data','avatar_url')
        }
      end

      # Получение базовой информации о пользователе
      def raw_info
        @raw_info ||= access_token.get(
          '/oauth/userinfo',
          headers: { 'Authorization' => "Bearer #{access_token.token}" }
        ).parsed
      end

      # callback_url должен точно совпадать с тем, что в Dev Console
      def callback_url
        options.redirect_uri || super
      end
    end
  end
end
