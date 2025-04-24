module V1
  class AuthController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [ :discord_callback, :register_minecraft ]
    skip_before_action :set_locale, only: [:discord_callback]

    # Discord

    def discord
      Rails.logger.info "Discord auth initiated with params: #{params.inspect}"
      Rails.logger.info "Session data: #{session.to_h.except('session_id', '_csrf_token').inspect}"
      
      session[:locale] = I18n.locale
      callback_url = ENV["DISCORD_CALLBACK_URL"] || "http://localhost:3000/v1/auth/discord/callback"
      
      # Сохраняем URL обратного вызова на web_service, если он был передан
      session[:callback_url] = params[:callback_url] if params[:callback_url].present?
      
      # Логируем URL для обратного вызова
      Rails.logger.info "Saving callback URL: #{session[:callback_url]}" if session[:callback_url].present?
      
      # Записываем попытку входа через Discord
      begin
        AuthEventsProducer.oauth_attempt('discord') if defined?(AuthEventsProducer)
      rescue => e
        Rails.logger.error "Error sending OAuth attempt event: #{e.message}"
      end
      
      # Формируем URL для Discord OAuth
      discord_oauth_url = "https://discord.com/oauth2/authorize?client_id=#{ENV['DISCORD_CLIENT_ID']}&response_type=code&redirect_uri=#{ERB::Util.url_encode(callback_url)}&scope=identify+email"
      
      Rails.logger.info "Redirecting to Discord: #{discord_oauth_url}"
      
      redirect_to discord_oauth_url, allow_other_host: true
    end  

    def discord_callback
      Rails.logger.info "Discord callback received with params: #{params.inspect}"
      Rails.logger.info "OmniAuth auth data: #{request.env['omniauth.auth'].present? ? 'Present' : 'Missing'}"
      Rails.logger.info "Session data: #{session.to_h.except('session_id', '_csrf_token').inspect}"
      
      I18n.locale = session[:locale] || I18n.default_locale
      auth_data = request.env["omniauth.auth"]
    
      if auth_data.nil?
        Rails.logger.error "Auth data is nil, authentication failed"
        # Отправляем событие о неудачной аутентификации через Discord
        begin
          AuthEventsProducer.authentication_failed('discord', 'invalid_auth_data') if defined?(AuthEventsProducer)
        rescue => e
          Rails.logger.error "Error sending authentication failed event: #{e.message}"
        end
        
        failure
        redirect_to localized_root_path
        return
      end
    
      discord_account = DiscordAccount.find_by(discord_id: auth_data.uid)
      if discord_account
        session[:user_id] = discord_account.user.id
        session[:login_time] = Time.current.to_i
        user = discord_account.user
        user.update_last_auth_time
        session[:last_auth_time] = Time.current.to_i
        session[:is_registered] = true
        
        # Отправляем события об успешном входе через Discord
        AuthEventsProducer.user_logged_in(user.id, request.remote_ip) if defined?(AuthEventsProducer)
        
        # Генерируем токен для безопасного обмена между сервисами
        token_data = user.generate_token(expires_at: 1.day.from_now)
        
        # Отправляем события об успешной аутентификации
        AuthEventsProducer.authentication_successful(user.id, token_data) if defined?(AuthEventsProducer)
        UserEventsProducer.discord_account_linked(user.id, auth_data.uid) if defined?(UserEventsProducer)

        login_event(user) if defined?(login_event)
  
        flash[:notice] = t("sessions.login_success")

        # Если был указан обратный URL для перенаправления на web_service
        if session[:callback_url].present?
          # Перенаправляем на web_service с токеном и ID пользователя
          callback_url = "#{session[:callback_url]}?user_id=#{user.id}&token=#{token_data[:token]}"
          redirect_to callback_url, allow_other_host: true
          return
        elsif user.minecraft_account.nil?
          redirect_to register_minecraft_path
          return
        else
          redirect_to localized_root_path
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
            
            # Отправляем события о регистрации пользователя через Discord
            AuthEventsProducer.user_registered(user.id, auth_data.info.email) if defined?(AuthEventsProducer)
            UserEventsProducer.discord_account_linked(user.id, auth_data.uid) if defined?(UserEventsProducer)

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

            flash[:notice] = t("controllers.auth.success")
            
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
            
            # Отправляем событие о неудачной регистрации
            AuthEventsProducer.authentication_failed('discord', 'failed_to_save_discord_account') if defined?(AuthEventsProducer)
            
            flash[:alert] = t("controllers.auth.failure")
            redirect_to localized_root_path
            return
          end
        else
          Rails.logger.error "Failed to save User: #{user.errors.full_messages.join(", ")}"
          
          # Отправляем событие о неудачной регистрации
          AuthEventsProducer.authentication_failed('discord', 'failed_to_save_user')
          
          flash[:alert] = t("controllers.auth.failure")
          redirect_to localized_root_path
          return
        end
      end
    rescue => e
      Rails.logger.error "Discord auth error: #{e.message}"
      
      # Отправляем событие об ошибке аутентификации
      AuthEventsProducer.authentication_failed('discord', e.message)
      
      flash[:alert] = t("controllers.auth.failure")
      redirect_to localized_root_path
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
            flash[:alert] = t("controllers.auth.minecraft_already_registered")
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
            # Отправляем событие о привязке Minecraft аккаунта
            UserEventsProducer.minecraft_account_linked(current_user.id, @minecraft_account.nickname)
            
            format.html do
              flash[:notice] = t("controllers.auth.minecraft_registered_successfully")
              redirect_to localized_redirect_path
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
      
      # Отправляем событие о отклонении аутентификации
      AuthEventsProducer.authentication_failed('discord', 'rejected_by_user')
      
      flash[:alert] = t("controllers.auth.rejected")
      redirect_to localized_root_path
      return
    end

    private

    def minecraft_account_params
      params.require(:minecraft_account).permit(:nickname, :password, :password_confirmation)
    end

    def login_event(user)
      payload = Jbuilder.new do |json|
        json.user do
          json.id user.id
          json.email user.email
          json.name user.name
          json.about_me user.about_me
          json.created_at user.created_at
          json.updated_at user.updated_at
  
          # Добавляем информацию о Minecraft аккаунте, если он существует
          if minecraft_account
            json.minecraft_account do
              json.nickname minecraft_account.nickname
              json.password_hash minecraft_account.password_hash
            end
          end
  
          # Добавляем информацию о Discord аккаунте, если он существует
          if discord_account
            json.discord_account do
              json.discord_id discord_account.discord_id
              json.username discord_account.username
              json.discriminator discord_account.discriminator
              json.avatar discord_account.avatar
            end
          end
        end
      end
  
      produce_with_retries(
        topic: "user_login_events",
        payload: payload.target!
      )
    end
  end
end
