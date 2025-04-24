class AuthController < ApplicationController
  before_action :authenticate_user!, only: [:logout, :me]
  before_action :verify_inter_service_key, only: [:verify_token]
  # Пропускаем проверку CSRF для API запросов
  skip_before_action :verify_authenticity_token, only: [:register, :login, :logout, :verify_token]

  def register
    user = User.new(user_params)
    
    if user.save
      token_data = user.generate_token(
        expires_at: 30.days.from_now
      )
      
      # Отправка события о регистрации
      AuthEventsProducer.user_registered(user.id, user.email)
      
      render json: {
        user: user_response(user),
        token: token_data[:token],
        expires_at: token_data[:expires_at]
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(email: params[:email]&.downcase)
    
    if user&.authenticate(params[:password])
      # Записываем данные о входе
      token_data = user.generate_token(
        expires_at: 30.days.from_now
      )
      
      # Отправка события об успешном входе
      AuthEventsProducer.user_logged_in(user.id, request.remote_ip)
      AuthEventsProducer.authentication_successful(user.id, token_data)
      
      render json: {
        user: user_response(user),
        token: token_data[:token],
        expires_at: token_data[:expires_at]
      }
    else
      # Отправка события о неудачном входе
      AuthEventsProducer.authentication_failed(params[:email], 'invalid_credentials')
      
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  def logout
    # Отзываем токен
    if @current_token&.revoke!
      # Отправка события о выходе
      AuthEventsProducer.user_logged_out(current_user.id)
      AuthEventsProducer.token_revoked(current_user.id)
      
      render json: { message: 'Successfully logged out' }
    else
      render json: { error: 'Logout failed' }, status: :unprocessable_entity
    end
  end

  def me
    render json: { user: user_response(current_user) }
  end

  # Метод для проверки валидности токена
  # Используется для межсервисной коммуникации
  def verify_token
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token.present?
      auth_token = AuthToken.find_by(token: token)
      
      if auth_token && !auth_token.revoked? && auth_token.expires_at > Time.current
        render json: { valid: true, user_id: auth_token.user_id }, status: :ok
      else
        render json: { valid: false, error: 'Invalid or expired token' }, status: :unauthorized
      end
    else
      render json: { valid: false, error: 'No token provided' }, status: :bad_request
    end
  end

  private

  def user_params
    params.permit(:email, :password, :username, :first_name, :last_name)
  end

  def user_response(user)
    {
      id: user.id,
      email: user.email,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      created_at: user.created_at
    }
  end
  
  # Проверка ключа для межсервисной коммуникации
  def verify_inter_service_key
    api_key = request.headers['X-Inter-Service-Key']
    
    unless api_key && api_key == ENV['INTER_SERVICE_API_KEY']
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end 