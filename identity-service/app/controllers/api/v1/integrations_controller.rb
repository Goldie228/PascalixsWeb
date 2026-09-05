module Api
  module V1
    class IntegrationsController < ApplicationController
      skip_before_action :authenticate_service_request, only: [
        :youtube, :youtube_callback, :failure,
        :twitch,  :twitch_callback,  :twitch_failure
      ]
      skip_before_action :verify_authenticity_token, only: [
        :youtube_callback,
        :twitch_callback
      ]
      skip_before_action :set_locale, only: [
        :youtube_callback,
        :twitch_callback
      ]

      def youtube
        drop_session_flash
        session[:locale]      = I18n.locale
        session[:callback_url] = params[:callback_url] if params[:callback_url].present?

        base     = ENV.fetch("IDENTITY_SERVICE_URL")
        version  = ENV.fetch("AUTH_VERSION")
        uri      = "#{base}/api/#{version}/integrations/youtube/callback"
        client   = ENV.fetch("GOOGLE_CLIENT_ID")
        scope    = [
          "email",
          "profile",
          "https://www.googleapis.com/auth/youtube.readonly"
        ].join(" ")

        redirect_to(
          "https://accounts.google.com/o/oauth2/auth?" +
          "client_id=#{client}&" +
          "redirect_uri=#{ERB::Util.url_encode(uri)}&" +
          "response_type=code&" +
          "scope=#{ERB::Util.url_encode(scope)}&" +
          "access_type=offline&prompt=consent",
          allow_other_host: true
        )
      end

      def youtube_callback
        auth = request.env["omniauth.auth"]
        return failure unless auth&.credentials&.token

        # restore locale & flash
        I18n.locale = session.delete(:locale) || I18n.default_locale
        drop_session_flash

        # extract email from OAuth
        oauth_email = auth.info.email
        Rails.logger.info "OAuth email: #{oauth_email}"

        # find the discord_account by email, then its owner
        discord_account = DiscordAccount.find_by(email: oauth_email)
        user = discord_account&.user

        unless user
          session[:alert] = I18n.t('integrations.youtube.user_not_found')
          return redirect_to profile_path(locale: I18n.locale)
        end

        begin
          account = Yt::Account.new(access_token: auth.credentials.token)
          channel = account.channels.first

          unless channel.present?
            return failure
          end

          snippet = channel.snippet
          unless snippet.title.present?
            return failure
          end

          youtube_url =
            if snippet.respond_to?(:customUrl) && snippet.customUrl.present?
              "https://www.youtube.com/#{snippet.customUrl}"
            else
              "https://www.youtube.com/channel/#{channel.id}"
            end

          user.update!(
            youtube_channel_name: snippet.title,
            youtube_url:          youtube_url
          )

          session[:notice] = I18n.t('integrations.youtube.confirmed')
        rescue => e
          Rails.logger.error "YouTube link error: #{e.class} – #{e.message}"
          return failure
        end

        redirect_to(
          session.delete(:callback_url) || profile_path,
          locale: I18n.locale
        )
      end

      # 1) Старт OAuth для Twitch
      def twitch
        drop_session_flash
        session[:locale]      = I18n.locale
        session[:callback_url] = params[:callback_url] if params[:callback_url].present?

        base    = ENV.fetch("IDENTITY_SERVICE_URL")
        version = ENV.fetch("AUTH_VERSION")
        uri     = "#{base}/api/#{version}/integrations/twitch/callback"
        client  = ENV.fetch("TWITCH_CLIENT_ID")
        scope   = "user:read:email"

        redirect_to(
          "https://id.twitch.tv/oauth2/authorize?" +
          "client_id=#{client}&" +
          "redirect_uri=#{ERB::Util.url_encode(uri)}&" +
          "response_type=code&" +
          "scope=#{ERB::Util.url_encode(scope)}&" +
          "force_verify=true",
          allow_other_host: true
        )
      end

      # 2) Callback от Twitch
      def twitch_callback
        code = params.require(:code)
        client_id     = ENV.fetch("TWITCH_CLIENT_ID")
        client_secret = ENV.fetch("TWITCH_CLIENT_SECRET")
        redirect_uri  = "#{ENV.fetch("IDENTITY_SERVICE_URL")}/api/#{ENV.fetch("AUTH_VERSION")}/integrations/twitch/callback"

        # restore locale & flash
        I18n.locale = session.delete(:locale) || I18n.default_locale
        drop_session_flash

        # 1) Обмен code → access_token
        token_res = Faraday.post("https://id.twitch.tv/oauth2/token", {
          client_id:     client_id,
          client_secret: client_secret,
          code:          code,
          grant_type:    "authorization_code",
          redirect_uri:  redirect_uri
        })
        token_body = JSON.parse(token_res.body)
        access_token = token_body["access_token"]
        unless access_token
          return twitch_failure
        end

        # 2) Получаем профиль
        user_res = Faraday.get("https://api.twitch.tv/helix/users", {}, {
          "Authorization" => "Bearer #{access_token}",
          "Client-ID"     => client_id
        })
        user_data = JSON.parse(user_res.body)["data"]&.first
        Rails.logger.info user_data
        unless user_data
          return twitch_failure
        end

        oauth_email   = user_data["email"]
        twitch_login  = user_data["login"]
        twitch_url    = "https://twitch.tv/#{twitch_login}"

        # find the discord_account by email, then its owner
        discord_account = DiscordAccount.find_by(email: oauth_email)
        user = discord_account&.user

        unless user
          session[:alert] = I18n.t('integrations.twitch.user_not_found')
          return redirect_to profile_path(locale: I18n.locale)
        end

        user.update!(
          twitch_channel_name: twitch_login,
          twitch_url:          twitch_url
        )

        session[:notice] = I18n.t('integrations.twitch.confirmed')
        redirect_to(
          session.delete(:callback_url) || profile_path,
          locale: I18n.locale
        )
      end

      # Обработчик неуспешной привязки Twitch
      def twitch_failure
        I18n.locale = session[:locale] || I18n.default_locale
        drop_session_flash
        session[:alert] = I18n.t('integrations.twitch.failure')
        redirect_to profile_path(locale: I18n.locale)
      end

      def failure
        I18n.locale = session[:locale] || I18n.default_locale
        drop_session_flash
        session[:alert] = I18n.t('integrations.youtube.failure')
        redirect_to profile_path(locale: I18n.locale)
      end
    end
  end
end
