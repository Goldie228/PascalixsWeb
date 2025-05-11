class TwoFactorAuthenticationsController < ApplicationController
  include ActionController::Live

  before_action :check_user_session

  def show
    user_id = session[:user_id]

    @email = @current_user.discord_account.email

    @otp_valid_until = Time.now + 2.minutes

    produce_with_retries(
      "two_factor_requests",
      {
        type: "status_request",
        locale: I18n.locale,
        user_id: user_id
      }.to_json
    )

    TwoFactorResponseJob.perform_async(user_id)
    EmailResponseJob.perform_async(user_id)

    render :show
  end

  def verify
    # Попытка получить вложенные параметры; если их нет, возвращаем пустой хэш
    otp_params = params.fetch(:two_factor_authentication, {}).permit(:otp_attempt)
    otp_attempt = otp_params[:otp_attempt]&.strip

    # Валидация наличия кода
    if otp_attempt.blank?
      return render json: {
        success: false,
        error: t("two_factor_authentication.errors.empty_code")
      }
    end

    # Проверка длины и формата (только цифры, ровно 6)
    unless otp_attempt.match?(/^\d{6}$/)
      return render json: {
        success: false,
        error: t("two_factor_authentication.errors.invalid_length")
      }
    end

    # Отправка в Kafka (или дальнейшая логика)
    produce_with_retries(
      "two_factor_requests",
      {
        type: "verify_code",
        user_id: session[:user_id],
        code: otp_attempt
      }.to_json
    )

    render json: {
      success: true
    }

    CodeValidityJob.perform_async
  end

  def resend_code
    flash.now[:notice] = "Код отправлен!"
    redirect_to user_two_factor_authentication_path
  end

  def success_update
    session[:two_factor_passed] = true
    render json: { success: true }
  end

  def check_user_session
    redirect_to login_path unless @current_user
  end
end
