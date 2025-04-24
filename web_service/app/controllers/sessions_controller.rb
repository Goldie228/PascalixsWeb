class SessionsController < ApplicationController
  def new
    # Страница входа
    redirect_to localized_root_path if current_user
  end

  def create
    # В микросервисной архитектуре, этот контроллер должен перенаправлять запросы в auth_service
    # или использовать API auth_service для аутентификации
    
    # Для локальной разработки можно использовать заглушку
    if Rails.env.development?
      # Заглушка для локальной разработки
      session[:user_id] = 1
      session[:is_registered] = true
      redirect_to localized_root_path, notice: t('sessions.login_success')
    else
      # В production должно быть перенаправление на auth_service
      redirect_to "#{ENV['AUTH_SERVICE_URL']}/login"
    end
  end

  def destroy
    # Выход пользователя
    session[:user_id] = nil
    session[:is_registered] = nil
    session[:two_factor_authenticated] = nil
    
    # Публикуем событие в Kafka
    if current_user
      begin
        produce_with_retries(
          "user_logout_events",
          { user_id: current_user.id, timestamp: Time.current.to_i }.to_json
        )
      rescue => e
        Rails.logger.error "Failed to publish logout event: #{e.message}"
      end
    end
    
    redirect_to localized_root_path, notice: t('sessions.logout_success')
  end
end