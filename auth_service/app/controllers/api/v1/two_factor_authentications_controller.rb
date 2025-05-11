module Api
  module V1
    class TwoFactorAuthenticationsController < ApplicationController
      before_action :authenticate_user, only: [:show, :verify, :resend_code]

      def show
        Rails.logger.info("Show method called with params: #{params.inspect}")
        @user = current_user
        
        if @user.otp_secret.blank?
          @user.otp_secret = User.generate_otp_secret
          @user.save

          Rails.logger.info("Session expired, setting new OTP valid until and sending email")
          @otp_valid_until = set_otp_valid_until
          session[:otp_valid_until] = @otp_valid_until.to_i

          begin
            otp_code = @user.current_otp
            timezone = Time.zone.name
            send_two_factor_code_email(@user, otp_code, @otp_valid_until, timezone)
            Rails.logger.info("Email sent due to session expiration")
            session[:notice] = t('devise.two_factor_authentication.code_resent')
          rescue => e
            Rails.logger.error("Error sending code in show due to session expiration: #{e.message}")
            
            AuthEventsProducer.authentication_failed(@user.email)
          end
        end

        Rails.logger.info("Session[:otp_valid_until]: #{session[:otp_valid_until]}")
        if params[:resend] == 'true'
          result = send_2fa_via_kafka(@user)
          if result[:success]
            session[:notice] = t('devise.two_factor_authentication.code_resent')
          else
            session[:alert] = result[:message]
            
            # Отправляем событие о проблеме с повторной отправкой OTP
            AuthEventsProducer.authentication_failed(@user.email)
          end
        elsif session[:otp_valid_until] && Time.at(session[:otp_valid_until]) > Time.current
          @otp_valid_until = Time.at(session[:otp_valid_until])
        end
        
        @qr_code_url = @user.generate_otp_qr_code
        
        respond_to do |format|
          format.html
          format.json { render json: { status: "success", qr_code_url: @qr_code_url, valid_until: @otp_valid_until } }
        end
      end

      def verify
        @user = current_user

        if session[:otp_valid_until]
          @otp_valid_until = Time.at(session[:otp_valid_until])
        else
          @otp_valid_until = set_otp_valid_until
          session[:otp_valid_until] = @otp_valid_until.to_i
        end

        if @user.otp_secret.blank?
          @user.otp_secret = User.generate_otp_secret
          @user.save
        end

        @qr_code_url = @user.generate_otp_qr_code

        if @otp_valid_until < Time.current
          # Отправляем событие о просроченном OTP коде
          AuthEventsProducer.authentication_failed(@user.email)
          
          session[:alert] = t('devise.two_factor_authentication.code_expired')
          render :show
          return
        end

        begin
          require 'rotp'
          totp = ROTP::TOTP.new(@user.otp_secret, drift_behind: 120, drift_ahead: 120)
          expected_otp = totp.now
          
          if @user.validate_and_consume_otp!(params[:otp_attempt])
            session[:is_registered] = true
            session.delete(:otp_valid_until)
            @user.update_last_auth_time
            
            # Отправляем событие об успешной двухфакторной аутентификации
            token_data = { token: SecureRandom.hex(10), expires_at: 1.day.from_now }
            AuthEventsProducer.authentication_successful(@user.id, token_data)
            
            redirect_to localized_root_path, notice: t('devise.two_factor_authentication.success')
          else
            # Отправляем событие о неудачной двухфакторной аутентификации
            AuthEventsProducer.authentication_failed(@user.email)
            
            session[:alert] = t('devise.two_factor_authentication.invalid_code')
            render :show
          end
        rescue => e
          # Отправляем событие о ошибке при проверке OTP
          AuthEventsProducer.authentication_failed(@user.email)
          
          session[:alert] = t('devise.two_factor_authentication.invalid_code')
          render :show
        end
      end

      def resend_code
        @user = current_user
        @otp_valid_until = set_otp_valid_until
        session[:otp_valid_until] = @otp_valid_until.to_i
        
        result = send_2fa_via_kafka(@user)
        if result[:success]
          session[:notice] = t('devise.two_factor_authentication.code_resent')
        else
          # Отправляем событие о проблеме с повторной отправкой OTP
          AuthEventsProducer.authentication_failed(@user.email)
          
          session[:alert] = result[:message]
        end
        redirect_to user_two_factor_authentication_path
      end

      def setup
        # Настройка 2FA
        unless current_user.otp_required_for_login?
          current_user.otp_secret = User.generate_otp_secret
          current_user.save
          
          @qr_code = current_user.generate_otp_qr_code
        end
      end

      def enable
        if current_user.validate_and_consume_otp!(params[:otp_code])
          current_user.update(otp_required_for_login: true)
          
          # Отправляем событие о включении 2FA
          UserEventsProducer.two_factor_enabled(current_user.id)
          
          redirect_to account_settings_path, notice: t('controllers.two_factor_authentications.enabled')
        else
          session[:alert] = t('controllers.two_factor_authentications.invalid_code')
          render :setup
        end
      end

      def disable
        if current_user.validate_and_consume_otp!(params[:otp_code])
          current_user.update(otp_required_for_login: false)
          
          # Отправляем событие о отключении 2FA
          UserEventsProducer.two_factor_disabled(current_user.id)
          
          redirect_to account_settings_path, notice: t('controllers.two_factor_authentications.disabled')
        else
          session[:alert] = t('controllers.two_factor_authentications.invalid_code')
          render :disable_form
        end
      end

      private

      def authenticate_user
        redirect_to login_path, alert: t('devise.failure.unauthenticated') unless current_user
      end

      def set_otp_valid_until
        Time.current.in_time_zone(current_user.time_zone) + 120
      end

      def send_two_factor_code_email(user, code, otp_valid_until, timezone)
        UserMailer.two_factor_code(user, code, otp_valid_until, timezone).deliver_now
      end

      def send_2fa_via_kafka(user)
        produce_with_retries(
          topic: 'send_2fa_events', 
          payload: {
            user_id: user.id,
            code: user.current_otp,
            otp_valid_until: session[:otp_valid_until],
            timezone: Time.zone.name
          }.to_json
        )
      end

      def current_user
        @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
      end
    end
  end
end
