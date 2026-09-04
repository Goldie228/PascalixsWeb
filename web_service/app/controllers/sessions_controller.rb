class SessionsController < ApplicationController
  def new
    redirect_to localized_root_path if current_user

    flash.clear
    correlation_id = SecureRandom.uuid
    session[:login_correlation_id] = correlation_id
  end

  def update
    Rails.logger.info "Все параметры запроса: #{params.to_json}"

    session[:user_id] = params[:user_id]

    Rails.logger.info "Параметр user_id: #{params[:user_id]}"
    Rails.logger.info "Сессия user_id после записи: #{session[:user_id]}"

    render json: { message: "Сессия обновлена", user_id: session[:user_id] }, status: :ok
  end

  def create
    correlation_id = session[:login_correlation_id]

    unless correlation_id
      correlation_id = SecureRandom.uuid
      session[:login_correlation_id] = correlation_id
    end

    # Посылаем событие логина (обычно в ваш брокер, например, Kafka)
    produce_with_retries(
      'identity.user.logged_in',
      {
        correlation_id: correlation_id,
        nickname: params[:nickname],
        password: params[:password]
      }.to_json
    )

    LoginResponseJob.perform_later(correlation_id)

    render json: {
      status: "pending",
      message: "Login is in process",
      correlation_id: correlation_id
    }, status: :accepted
  end

  def destroy
    REDIS_CLIENT.del("user_updates::#{session[:user_id]}") if session[:user_id]
    session[:user_id] = nil
    cookies[:user_id] = nil
    session[:two_factor_passed] = nil
    cookies[:two_factor_passed] = nil

    flash.clear
    session[:notice] = t("sessions.logout_success")

    redirect_to localized_root_path
  end

  def email_login
  end

  def verify_email
    email = params[:email].to_s.strip

    # 1. Базовая валидация почты
    unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
      return render json: {
        errors: {
          email: ['Некорректный формат email']
        }
      }, status: :unprocessable_entity
    end

    begin
      # 2. Проверка, есть ли такая почта вообще в базе
      email_check_response = AuthServiceClient.lookup_email(email)

      unless email_check_response
        error_message = email_check_response&.dig('message') || 'Почта не найдена' if email_check_response
        error_message ||= 'Почта не найдена'
        return render json: {
          errors: {
            email: [error_message]
          }
        }, status: :not_found
      end

      user_id  = email_check_response['user_id']
      nickname = email_check_response['nickname']

      token = SecureRandom.hex(32)

      REDIS_CLIENT.set(
        "login_token:#{token}",
        { email: email, user_id: user_id }.to_json,
        ex: 2.hours.to_i
      )

      produce_with_retries('notification.password_reset.sent', {
        token: token,
        email: email,
        nickname: nickname,
        locale: I18n.locale,
        time_zone: session[:time_zone] || 'UTC'
      }.to_json)

      session[:sended_email] = email
      session[:email_login] = true
      session[:login_correlation_id]

      render json: {
        success: true,
        message: 'Инструкции отправлены'
      }, status: :ok

    rescue => e
      Rails.logger.error "Email verification error: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: {
        errors: {
          base: ['Произошла ошибка при обработке запроса']
        }
      }, status: :internal_server_error
    end
  end
end
