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

        Rails.logger.info "✅ SET oauth_state: #{session[:oauth_state]}"

        redirect_to auth_url, allow_other_host: true
      end

      # 2) Callback: TikTok возвращает ?code=…&state=…
      def callback
        stored_state = session[:oauth_state]
        Rails.logger.info "✅ STORED STATE: #{stored_state}"
        Rails.logger.info "✅ PARAM STATE: #{params[:state]}"
        Rails.logger.info "Stored: #{stored_state}, Param: #{params[:state]}"
        Rails.logger.info "🔁 TikTok token response: #{response.body}"
        Rails.logger.info "🔐 Using client_key=#{CLIENT_KEY}, client_secret=#{CLIENT_SECRET.present?}"

        if stored_state != params[:state]
          render json: { error: 'State mismatch' }, status: :forbidden
        else
          session.delete(:oauth_state)
        end


        unless params[:state] == stored_state
          return render json: { error: 'State mismatch' }, status: :forbidden
        end

        code = params[:code]
        unless code
          return render json: { error: 'No code provided' }, status: :bad_request
        end

        # 2.2 Обмен code → access_token
        token_data = exchange_code_for_token(code)
        unless token_data && token_data['access_token']
          return render json: { error: 'Token exchange failed' }, status: :unprocessable_entity
        end

        access_token = token_data['access_token']
        open_id      = token_data['open_id']

        # 2.3 Получение данных пользователя
        user_info = fetch_user_info(access_token, open_id)
        Rails.logger.info "👤 TikTok user_info response: #{user_info.inspect}"
        unless user_info && user_info['data']
          return render json: { error: 'Failed to fetch user info' }, status: :unprocessable_entity
        end

        user_data  = user_info.dig('data', 'user')
        username   = user_data['username']
        profile_url = user_data['profile_deep_link'] || "https://www.tiktok.com/@#{username}"

        tiktok_url = "https://www.tiktok.com/@#{username}" if username.present?

        user = User.find_by(id: session[:user_id])
        unless user
          Rails.logger.warn "❌ Не найден пользователь по session[:user_id] = #{session[:user_id]}"
          return render json: { error: 'User not found' }, status: :not_found
        end

        user.update!(
          tiktok_channel_name:   username,
          tiktok_url:            tiktok_url
        )

        Rails.logger.info "✅ TikTok привязан к #{user.id}: @#{username}"

        # 2.5 Редирект или JSON-ответ
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

        Rails.logger.info "🔁 TikTok token response: #{response.body}"
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
