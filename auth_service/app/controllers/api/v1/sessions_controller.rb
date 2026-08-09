module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :require_login, only: [:destroy]

      def new
      end
      
      def create
        if request.post? && current_user.nil?
          result = authenticate_user(params[:nickname], params[:password])
          
          if result[:success]
            if should_require_2fa?
              setup_session(result[:user])
              send_2fa_email(result[:user])
              render json: {
                status: "success",
                message: t('devise.two_factor_authentication.required'),
                redirect_to: api_v1_two_factor_authentication_path(locale: I18n.locale)
              }, status: :ok
            else
              setup_session(result[:user])
              session[:last_auth_time] = Time.current.to_i
              session[:is_registered] = true
              
              AuthEventsProducer.user_logged_in(result[:user].id, request.remote_ip)
              
              send_login_event(result[:user])
              
              render json: {
                status: "success",
                message: t("sessions.login_success"),
                redirect_to: localized_root_path
              }, status: :created
            end
          else
            session[:is_registered] = true
            
            AuthEventsProducer.authentication_failed(params[:nickname], result[:message])
            
            render json: {
              status: "error",
              message: result[:message]
            }, status: :unprocessable_entity
          end
        end  
      end

      def destroy
        if session[:user_id]
          user_id = session[:user_id]
          
          AuthEventsProducer.user_logged_out(user_id)
          
          session.delete(:user_id)
          session.delete(:is_registered)
          redirect_to localized_root_path, notice: t("sessions.logout_success")
        else
          redirect_to localized_root_path
        end
      end

      private
      
      def require_login
        unless session[:user_id]
          flash[:alert] = t("sessions.login_required")
          redirect_to localized_root_path
        end
      end

      def authenticate_user(nickname, password)
        if nickname.blank? || password.blank?
          return { success: false, message: t("sessions.missing_credentials") }
        end

        user = User.joins(:minecraft_account).find_by(minecraft_accounts: { nickname: nickname })
        
        if user && user.minecraft_account.authenticate(password)
          { success: true, user: user }
        else
          { success: false, message: t("sessions.login_failure") }
        end
      end

      def setup_session(user)
        session[:user_id] = user.id
        session[:is_registered] = false
        session[:login_time] = Time.current.to_i
        
        cookies.signed[:last_login_time] = { value: Time.current.to_i, expires: 1.year.from_now }
        cookies.signed[:device_id] ||= { value: SecureRandom.uuid, expires: 1.year.from_now }
      end

      def should_require_2fa?
        last_login = cookies.signed[:last_login_time]
        device_id = cookies.signed[:device_id]
        last_login.nil? || device_id.nil? || last_login < 1.week.ago.to_i
      end

      def send_2fa_email(user)
        begin
          otp_valid_until = Time.current.in_time_zone(user.time_zone) + 120
          session[:otp_valid_until] = otp_valid_until.to_i
          totp = ROTP::TOTP.new(user.otp_secret, drift_behind: 120, drift_ahead: 120)
          otp_code = totp.now
          UserMailer.two_factor_code(user, otp_code, otp_valid_until, Time.zone.name).deliver_now
        rescue => e
          Rails.logger.error("Error sending 2FA email: #{e.message}")
        end
      end

      def send_login_event(user)
        produce_with_retries(
          'user_login_events',
          { user_id: user.id, login_time: Time.current.to_i, action: "logged_in" }.to_json
        )
        
        token_data = { token: SecureRandom.hex(10), expires_at: 1.day.from_now }
        AuthEventsProducer.authentication_successful(user.id, token_data)
      end
    end
  end
end