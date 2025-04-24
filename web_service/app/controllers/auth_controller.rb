class AuthController < ApplicationController  
  def login
    # Отправляем событие о попытке входа через WebEventsProducer
    WebEventsProducer.user_action(
      nil, # пока нет user_id
      'login_attempt',
      { email: params[:email] }
    )
    
    # Сохраняем старый код для обратной совместимости
    payload = {
      email: params[:email],
      password: params[:password],
      request_id: SecureRandom.uuid,
      timestamp: Time.now.to_i,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    }.to_json
    
    # Отправляем сообщение в тему user_login_events
    begin
      produce_with_retries('user_login_events', payload)
      
      # Поскольку нам все равно нужен синхронный ответ для пользователя,
      # делаем запрос к auth_service, но уже после отправки события
      response = HTTParty.post("http://auth_service:3000/v1/sessions",
        body: params.permit(:email, :password).to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      
      # Если авторизация успешна, отправляем событие о входе пользователя
      if response.code == 200 || response.code == 201
        begin
          user_data = JSON.parse(response.body)
          if user_data['user'] && user_data['user']['id']
            # Теперь у нас есть user_id, можно отправить событие через UserEventsProducer
            UserEventsProducer.user_logged_in({
              id: user_data['user']['id'],
              email: user_data['user']['email']
            })
            
            # Записываем пользователя в сессию
            session[:user_id] = user_data['user']['id']
            session[:is_registered] = true
          end
        rescue => e
          Rails.logger.error("Error processing successful login response: #{e.message}")
        end
      end
      
      render json: response.body, status: response.code
    rescue => e
      # Отправляем событие об ошибке при входе
      WebEventsProducer.error_occurred(
        nil, # нет user_id при неудачном входе
        'login_error',
        e.message,
        request.path
      )
      
      Rails.logger.error("Failed to produce login event: #{e.message}")
      render json: { error: "Authentication service temporarily unavailable" }, status: :service_unavailable
    end
  end
  
  def logout
    user_id = session[:user_id]
    
    # Отправляем событие о попытке выхода через WebEventsProducer
    WebEventsProducer.user_action(
      user_id,
      'logout_attempt',
      {}
    )
    
    # Сохраняем старый код для обратной совместимости
    payload = {
      token: request.headers['Authorization']&.split(' ')&.last,
      request_id: SecureRandom.uuid,
      timestamp: Time.now.to_i,
      ip_address: request.remote_ip
    }.to_json
    
    # Отправляем сообщение в тему user_logout_events
    begin
      produce_with_retries('user_logout_events', payload)
      
      # Поскольку нам все равно нужен синхронный ответ для пользователя,
      # делаем запрос к auth_service, но уже после отправки события
      response = HTTParty.delete("http://auth_service:3000/v1/sessions",
        headers: { 'Authorization' => request.headers['Authorization'] }
      )
      
      # Если запрос успешен, отправляем событие о выходе пользователя
      if response.code == 200 || response.code == 204
        UserEventsProducer.user_logged_out(user_id) if user_id.present?
        
        # Удаляем данные сессии
        session.delete(:user_id)
        session.delete(:is_registered)
      end
      
      render json: response.body, status: response.code
    rescue => e
      # Отправляем событие об ошибке при выходе
      WebEventsProducer.error_occurred(
        user_id,
        'logout_error',
        e.message,
        request.path
      )
      
      Rails.logger.error("Failed to produce logout event: #{e.message}")
      render json: { error: "Authentication service temporarily unavailable" }, status: :service_unavailable
    end
  end

  def discord
    # Отправляем событие о попытке входа через Discord
    WebEventsProducer.user_action(
      nil,
      'discord_auth_attempt',
      {}
    ) if defined?(WebEventsProducer)
    
    # В микросервисной архитектуре, этот метод перенаправляет на auth_service
    if Rails.env.production?
      redirect_to "#{ENV['AUTH_SERVICE_URL']}/auth/discord"
    else
      # Для локальной разработки заглушка
      redirect_to "/auth/callback", notice: "Callback для локальной разработки"
    end
  end

  def callback
    # Отправляем событие о завершении аутентификации через Discord
    WebEventsProducer.page_viewed(
      params[:user_id],
      request.path,
      request.referrer
    ) if defined?(WebEventsProducer)
    
    # Этот метод обрабатывает callback от auth_service после авторизации
    # В реальной имплементации здесь должна быть проверка токена или другой механизм
    # аутентификации между микросервисами
    
    # Получаем данные из параметров запроса (в реальной системе должна быть проверка)
    user_id = params[:user_id]
    if user_id.present?
      session[:user_id] = user_id
      session[:is_registered] = true
      redirect_to localized_root_path, notice: t('controllers.auth.success')
    else
      redirect_to localized_root_path, alert: t('controllers.auth.failure')
    end
  end
end 