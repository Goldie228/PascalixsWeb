module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_service_request, only: [:discord, :discord_callback, :failure]
      skip_before_action :verify_authenticity_token, only: [:discord_callback, :register_minecraft]
      skip_before_action :set_locale, only: [:discord_callback]

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
        client_id = ENV['DISCORD_CLIENT_ID']
      
        redirect_to "https://discord.com/oauth2/authorize?" \
                    "client_id=#{client_id}&" \
                    "response_type=code&" \
                    "redirect_uri=#{ERB::Util.url_encode(callback_uri)}&" \
                    "scope=identify+email",
                    allow_other_host: true
      end
      
      # Discord callback		

      def discord_callback
        Rails.logger.info "Discord callback received with params: #{params.inspect}"
        Rails.logger.info "OmniAuth auth data: #{request.env['omniauth.auth'].present? ? 'Present' : 'Missing'}"
        Rails.logger.info "Session data: #{session.to_h.except('session_id', '_csrf_token').inspect}"
        
        I18n.locale = session[:locale] || I18n.default_locale

        drop_session_flash

        auth_data = request.env["omniauth.auth"]
      
        if auth_data.nil?
          failure and return
        end
      
        discord_account = DiscordAccount.find_by(discord_id: auth_data.uid)

        Rails.logger.info "Discord account: #{discord_account.present? ? 'Present' : 'Missing'}"

        if discord_account
          session[:user_id] = discord_account.user.id
          session[:login_time] = Time.current.to_i

          user = discord_account.user
          user.update_last_auth_time
          
          # Генерируем токен для безопасного обмена между сервисами
          token_data = user.generate_token(expires_at: 1.day.from_now)

          if user
            UserDataProducer.publish(user)
          end
    
          session[:notice] = I18n.t("sessions.login_success")

          # Если был указан обратный URL для перенаправления на web_service
          if session[:callback_url].present?
            # Перенаправляем на web_service с токеном и ID пользователя
            callback_url = "#{session[:callback_url]}?user_id=#{user.id}&token=#{token_data[:token]}"
            redirect_to callback_url, allow_other_host: true
            return
          elsif user.minecraft_account.nil?
            redirect_to api_v1_register_minecraft_path
            return
          else
            redirect_to localized_root_path(locale: I18n.locale)
            return
          end
        end
      
        User.skip_email_validation do
          user = User.new(id: SecureRandom.uuid)
          if user.save
            discord_account = DiscordAccount.new(
              user: user,
              discord_id: auth_data.uid,
              username: auth_data.info.name,
              discriminator: auth_data.info.discriminator,
              email: auth_data.info.email,
              avatar: auth_data.info.image
            )
      
            if discord_account.save
              session[:user_id] = user.id
              session[:login_time] = Time.current.to_i
              user.update_last_auth_time
              session[:last_auth_time] = Time.current.to_i
              session[:is_registered] = true
              
              # Генерируем токен для безопасного обмена между сервисами
              token_data = user.generate_token(expires_at: 1.day.from_now)

              if defined?(produce_with_retries)
                produce_with_retries(
                  topic: "user_login_events",
                  payload: {
                    user_id: user.id,
                    login_time: Time.current.to_i,
                    action: "registered"
                  }.to_json
                )
              end

              session[:notice] = I18n.t("controllers.auth.success")
              
              # Если был указан обратный URL для перенаправления на web_service
              if session[:callback_url].present?
                # Перенаправляем на web_service с токеном и ID пользователя
                callback_url = "#{session[:callback_url]}?user_id=#{user.id}&token=#{token_data[:token]}"
                redirect_to callback_url, allow_other_host: true
                return
              else
                redirect_to register_minecraft_path
                return
              end
            else
              Rails.logger.error "Failed to save Discord account: #{discord_account.errors.full_messages.join(", ")}"
              user.destroy

              drop_session_flash
              
              session[:alert] = I18n.t("controllers.auth.failure")
              redirect_to localized_root_path(locale: I18n.locale)
              return
            end
          else
            Rails.logger.error "Failed to save User: #{user.errors.full_messages.join(", ")}"

            drop_session_flash
            
            session[:alert] = I18n.t("controllers.auth.failure")
            redirect_to localized_root_path(locale: I18n.locale)
            return
          end
        end
      rescue => e
        Rails.logger.error "Discord auth error: #{e.message}"

        drop_session_flash
        
        session[:alert] = I18n.t("controllers.auth.failure")
        redirect_to localized_root_path(locale: I18n.locale)
        return
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
        return
      end

      private

      def drop_session_flash
        session[:notice] = nil
        session[:alert] = nil
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