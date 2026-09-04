class ApplicationController < ActionController::API
  include ActionController::Flash
  include ActionController::Cookies
  include ActionController::Redirecting
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ActionController::RequestForgeryProtection
  include AbstractController::Translation

  protect_from_forgery with: :exception

  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { error: "forbidden" }, status: :forbidden
  end

  attr_reader :current_user, :current_token

  before_action :set_locale, :set_timezone, :authenticate_service_request
  after_action :set_locale_in_session

  before_action do
    sid = request.cookie_jar["_auth_service_session"]
    Rails.logger.debug "RAW COOKIE SID: #{sid.inspect}"
    Rails.logger.debug "Parsed session[:user_id]: #{session[:user_id].inspect}"
  end

  before_action do
    Rails.logger.debug "Cookie Header: #{request.headers['Cookie']}"
  end

  MAX_RETRIES = 10

  def produce_with_retries(topic, payload)
    retries = 0

    Rails.logger.info "Send..."

    loop do
      begin
        # Преобразуем payload в строку
        message = payload.to_json
        Karafka.producer.produce_async(
          topic: topic,
          payload: message
        )
        Rails.logger.info "Sended #{message})"
        break
      rescue => e
        if retries < MAX_RETRIES
          Rails.logger.error "Failed to produce to #{topic}: #{e.message}. Retrying... (Attempt #{retries + 1}/#{MAX_RETRIES})"
          retries += 1
        else
          Rails.logger.error "Failed to produce to #{topic} after #{MAX_RETRIES} attempts: #{e.message}"
          raise
        end
      end
    end
  end

  def drop_session_flash
    session[:notice] = nil
    session[:alert] = nil
  end

  def current_path
    request.fullpath
  end

  def default_locale
    I18n.default_locale
  end

  def default_url_options
    { locale: I18n.locale }
  end

  def locale
    I18n.locale.present? ? "/#{I18n.locale}" : "/"
  end

  def set_locale
    I18n.locale = params[:locale] || session[:locale] || I18n.default_locale
  end

  def set_locale_in_session
    session[:locale] = I18n.locale if I18n.locale != I18n.default_locale
  end

  def redirect_to_ru
    return if params[:locale].present? || session[:locale].present?
    preferred_locale = I18n.default_locale
    redirect_to localized_redirect_path(preferred_locale)
  end

  def check_two_factor_authentication
    redirect_to user_two_factor_authentication_path if current_user && current_user.require_two_factor_authentication? && !session[:two_factor_authenticated]
  end

  def require_two_factor_authentication?
    return false unless current_user
    return true if current_user.require_two_factor_authentication?
    false
  end

  def set_timezone
    request_timezone = params[:time_zone] || request.headers['X-Timezone'] || 'Moscow'
    session[:time_zone] ||= request_timezone
    session_timezone = session[:time_zone]

    return unless current_user && current_user.time_zone != session_timezone

    current_user.update(time_zone: session_timezone)
  end

  def authenticate_service_request
    auth_header = request.headers["Authorization"]

    # Extract token safely
    token = if auth_header.present?
      auth_header.sub(/^Bearer\s+/, "").strip
    else
      ""
    end

    expected_token = ENV["INTER_SERVICE_API_KEY"] || ""

    unless ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
      render json: { error: "unauthorized" }, status: :unauthorized and return
    end
  end

  def is_admin?
    user_id = request.headers["X-User-ID"]

    unless user_id.present?
      render json: { error: "missing X-User-ID header" }, status: :unauthorized
      return false
    end

    user = User.find_by(id: user_id)

    unless user && [ 3, 4 ].include?(user.role_id)
      render json: { error: "not admin" }, status: :forbidden
      return false
    end

    true
  end

  protected

  def authenticate_user!
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    authenticate_with_http_token do |token, options|
      @current_token = UserToken.find_active_token(token)
      @current_user = @current_token&.user
    end
  end

  def render_unauthorized
    headers['WWW-Authenticate'] = 'Token realm="Application"'
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  private

  def localized_redirect_path(locale = nil)
    locale ||= I18n.locale
    "/#{locale}#{request.fullpath}"
  end
end
