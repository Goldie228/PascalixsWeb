module Api
  module V1
    class TiktokController < ApplicationController
      skip_before_action :verify_authenticity_token, only: :start
      skip_before_action :authenticate_service_request, only: [ :start, :callback, :failure ]
      skip_before_action :set_locale, only: :callback

      CLIENT_KEY    = ENV['TIKTOK_CLIENT_KEY']
      CLIENT_SECRET = ENV['TIKTOK_CLIENT_SECRET']
      CALLBACK_URL  = "https://auth.pascalixs.fun/api/#{ENV.fetch("AUTH_VERSION", "v1")}/integrations/tiktok/callback"

      # 1) Старт OAuth: редиректим браузер на TikTok
      def start
        session[:oauth_state]   = SecureRandom.hex(16)
        session[:locale]        = I18n.locale
        session[:callback_url]  = params[:callback_url] if params[:callback_url].present?

        auth_url = URI::HTTPS.build(
          host: 'www.tiktok.com',
          path: '/v2/auth/authorize/',
          query: {
            client_key:    CLIENT_KEY,
            redirect_uri:  CALLBACK_URL,
            response_type: 'code',
            scope: 'user.info.basic,user.info.profile',
            state:         session[:oauth_state]
          }.to_query
        ).to_s

        redirect_to auth_url, allow_other_host: true
      end

      # 2) Callback: TikTok возвращает ?code=…&state=…
      def callback
        I18n.locale = session[:locale] || I18n.default_locale

        stored_state = session[:oauth_state]

        if stored_state != params[:state]
          session[:alert] = I18n.t("integrations.tiktok.failure")
          return redirect_to profile_path(locale: session.delete(:locale))
        end

        session.delete(:oauth_state)

        code = params[:code]
        unless code
          session[:alert] = I18n.t("integrations.tiktok.failure")
          return redirect_to profile_path(locale: session.delete(:locale))
        end

        token_data = exchange_code_for_token(code)
        unless token_data && token_data['access_token']
          session[:alert] = I18n.t("integrations.tiktok.failure")
          return redirect_to profile_path(locale: session.delete(:locale))
        end

        access_token = token_data['access_token']
        open_id      = token_data['open_id']

        user_info = fetch_user_info(access_token, open_id)

        unless user_info && user_info['data']
          session[:alert] = I18n.t("integrations.tiktok.failure")
          return redirect_to profile_path(locale: session.delete(:locale))
        end

        user_data   = user_info.dig('data', 'user')
        username    = user_data['username']
        profile_url = user_data['profile_deep_link'] || "https://www.tiktok.com/@#{username}"

        user = User.find_by(id: session[:user_id])
        unless user
          session[:alert] = I18n.t("integrations.tiktok.user_not_found")
          return redirect_to profile_path(locale: session.delete(:locale))
        end

        user.update!(
          tiktok_channel_name:   username,
          tiktok_url:            profile_url
        )

        session[:notice] = I18n.t("integrations.tiktok.confirmed")

        redirect_to profile_path(locale: session.delete(:locale))
      end

      private

      # Обмениваем полученный код на access_token
      def exchange_code_for_token(code)
        response = Faraday.post('https://open.tiktokapis.com/v2/oauth/token/') do |req|
          req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          req.body = {
            client_key:    CLIENT_KEY,
            client_secret: CLIENT_SECRET,
            code:          code,
            grant_type:    'authorization_code',
            redirect_uri:  CALLBACK_URL
          }.to_query
        end

        JSON.parse(response.body)
      rescue JSON::ParserError
        nil
      end

      # Получаем профиль пользователя
      def fetch_user_info(token, open_id)
        response = Faraday.get('https://open.tiktokapis.com/v2/user/info/') do |req|
          req.params['fields'] = 'open_id,avatar_url,display_name,username,profile_deep_link'
          req.params['open_id'] = open_id
          req.headers['Authorization'] = "Bearer #{token}"
        end

        JSON.parse(response.body)
      rescue JSON::ParserError
        nil
      end

      # Удобный путь к странице профиля вашего приложения
      def profile_path(locale:)
        "/#{locale}/profile"
      end
    end
  end
end
