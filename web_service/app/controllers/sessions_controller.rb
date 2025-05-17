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
      "user_login_events",
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
    session[:two_factor_passed] = nil

    flash.clear
    session[:notice] = t("sessions.logout_success")

    redirect_to localized_root_path
  end
end
