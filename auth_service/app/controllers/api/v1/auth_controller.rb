module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_service_request, only: [ :discord, :discord_callback, :failure ]
      skip_before_action :verify_authenticity_token, only: [ :discord_callback, :register_minecraft ]
      skip_before_action :set_locale, only: [ :discord_callback ]

      # Discord
      def discord
        # Устанавливаем локаль в сессию
        session[:locale] = I18n.locale
        locale = I18n.locale.to_s

        # Используем базовый URL для обратного вызова из переменной окружения,
        base_callback_url = ENV["AUTH_SERVICE_URL"]
        auth_version = ENV["AUTH_VERSION"]
        callback_uri = "#{base_callback_url}/api/#{auth_version}/auth/discord/callback"

        # Если передан дополнительный callback URL, сохраняем его в сессии
        session[:callback_url] = params[:callback_url] if params[:callback_url].present?

        # Получаем client_id из переменных окружения
        client_id = ENV["DISCORD_CLIENT_ID"]

        redirect_to(
          "https://discord.com/oauth2/authorize?" \
          "client_id=#{client_id}&" \
          "response_type=code&" \
          "redirect_uri=#{ERB::Util.url_encode(callback_uri)}&" \
          "scope=identify+email",
          allow_other_host: true
        )
      end

      # Discord callback
      def discord_callback
        Rails.logger.info "Discord callback received with params: #{params.inspect}"
        Rails.logger.info "OmniAuth auth data: #{request.env["omniauth.auth"].present? ? "Present" : "Missing"}"
        Rails.logger.info "Session data: #{session.to_h.except("session_id", "_csrf_token").inspect}"

        I18n.locale = session[:locale] || I18n.default_locale

        drop_session_flash

        auth_data = request.env["omniauth.auth"]
        return failure unless auth_data

        discord_account = DiscordAccount.find_by(username: auth_data.info.name, discriminator: auth_data.info.discriminator)
        Rails.logger.info "Discord account: #{discord_account.present? ? "Present" : "Missing"}"

        if discord_account&.user
          if discord_account.discord_id.ends_with?("_change")
            incoming_username      = auth_data.info.name
            incoming_discriminator = auth_data.info.discriminator

            if discord_account.username != incoming_username || discord_account.discriminator != incoming_discriminator
              Rails.logger.warn "🚫 Discord авторизация отклонена — данные не совпадают для user_id=#{discord_account.user_id}"
              drop_session_flash
              session[:alert] = I18n.t("controllers.auth.denied_discord")
              redirect_to localized_root_path(locale: I18n.locale)
              return
            else
              Rails.logger.info "✅ Discord ID отсутствует, но имя совпадает — доступ разрешён"
              discord_account.discord_id = auth_data.uid
            end
          end

          user = discord_account.user
          session[:user_id] = user.id
          session[:login_time] = Time.current.to_i
          session[:two_factor_passed] = true

          user.update_last_auth_time

          begin
            discord_account.assign_attributes(
              discord_id:    auth_data.uid,
              username:      auth_data.info.name,
              discriminator: auth_data.info.discriminator
            )
            discord_account.save!
          rescue => e
            Rails.logger.info "Error saving Discord account: #{e.class} - #{e.message}"
          end

          UserDataProducer.publish(user)
          token_data = user.generate_token(expires_at: 1.day.from_now)
          finalize_login_flow(user, token_data[:token])
          return
        end

        result = create_new_user_from_discord(auth_data)
        unless result
          drop_session_flash
          session[:alert] = I18n.t("controllers.auth.failure")
          redirect_to localized_root_path(locale: I18n.locale)
          return
        end

        finalize_login_flow(result[:user], result[:token])
      rescue => e
        Rails.logger.error "Discord auth error: #{e.message}"
        drop_session_flash
        session[:alert] = I18n.t("controllers.auth.failure")
        redirect_to localized_root_path(locale: I18n.locale)
      end

      # Minecraft
      def register_minecraft
        if current_user.nil?
          respond_to do |format|
            format.html { redirect_to localized_root_path }
            format.json { render "auth/register_minecraft_unauthorized", status: :unauthorized }
          end
          return
        end

        if current_user.minecraft_account.present?
          respond_to do |format|
            format.html do
              session[:alert] = I18n.t("controllers.auth.minecraft_already_registered")
              redirect_to localized_root_path
            end
            format.json { render "auth/register_minecraft_already_registered", status: :unprocessable_entity }
          end
          return
        end

        @minecraft_account = current_user.build_minecraft_account

        if request.post?
          @minecraft_account.assign_attributes(minecraft_account_params)

          respond_to do |format|
            if @minecraft_account.save

              format.html do
                session[:notice] = I18n.t("controllers.auth.minecraft_registered_successfully")
                redirect_to localized_root_path
              end

              login_event(current_user)

              format.json { render "auth/register_minecraft_success", status: :created }
            else
              format.html { render :register_minecraft, status: :unprocessable_entity }
              format.json { render "auth/register_minecraft_failure", status: :unprocessable_entity }
            end
          end
        end
      end

      def failure
        I18n.locale = session[:locale] || I18n.default_locale
        session.delete(:locale)

        drop_session_flash

        session[:alert] = I18n.t("controllers.auth.rejected")

        redirect_to localized_root_path
      end

      private

      def create_new_user_from_discord(auth_data)
        User.skip_email_validation do
          user = User.new(id: SecureRandom.uuid)
          return nil unless user.save

          discord_account = DiscordAccount.new(
            user:          user,
            discord_id:    auth_data.uid,
            username:      auth_data.info.name,
            discriminator: auth_data.info.discriminator,
            email:         auth_data.info.email,
            avatar:        auth_data.info.image
          )
          return nil unless discord_account.save

          discord_account.add_avatar(auth_data.info.image)

          user.update_last_auth_time

          session[:user_id]          = user.id
          session[:login_time]       = Time.current.to_i
          session[:last_auth_time]   = Time.current.to_i
          session[:is_registered]    = true
          session[:two_factor_passed] = true
          session[:notice]           = I18n.t("controllers.auth.success")

          token_data = user.generate_token(expires_at: 1.day.from_now)
          UserDataProducer.publish(user)

          { user:, token: token_data[:token] }
        rescue => e
          Rails.logger.error "[Auth] ❌ Ошибка при создании нового пользователя: #{e.message}"
          user&.destroy
          nil
        end
      end

      def finalize_login_flow(user, token)
        if session[:callback_url].present?
          callback_url = "#{session[:callback_url]}?user_id=#{user.id}&token=#{token}"
          redirect_to callback_url, allow_other_host: true
        elsif user.minecraft_account.nil?
          redirect_to api_v1_register_minecraft_path
        else
          redirect_to localized_root_path(locale: I18n.locale)
        end
      end

      def minecraft_account_params
        params.require(:minecraft_account).permit(:nickname, :password, :password_confirmation)
      end

      def login_event(user)
        payload = Jbuilder.new do |json|
          json.user do
            json.id user.id
            json.email user.email
            json.about_me user.about_me
            json.created_at user.created_at
            json.updated_at user.updated_at

            if user.minecraft_account
              json.minecraft_account do
                json.nickname user.minecraft_account.nickname
                json.password_hash user.minecraft_account.password_hash
              end
            end

            if user.discord_account
              json.discord_account do
                json.discord_id user.discord_account.discord_id
                json.username user.discord_account.username
                json.discriminator user.discord_account.discriminator
                json.avatar user.discord_account.avatar
              end
            end
          end
        end

        produce_with_retries(
          topic: "user_login_events",
          payload: payload.target!
        )
      rescue => e
        Rails.logger.error "Error generating login event: #{e.message}"
      end
    end
  end
end
