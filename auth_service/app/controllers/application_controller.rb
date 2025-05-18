class ApplicationController < ActionController::API
  include ActionController::Flash
  include ActionController::Cookies
  include ActionController::Redirecting
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ActionController::RequestForgeryProtection

  protect_from_forgery with: :exception

  attr_reader :current_user, :current_token

  before_action :set_locale, :set_timezone, :authenticate_service_request
  after_action :set_locale_in_session

  @max_retries = 3

  def produce_with_retries(topic, payload)
    retries = 0

    loop do
      begin
        Karafka.producer.produce_sync(
          topic: topic,
          payload: payload,
          acks: all
        )
        break
      rescue => e
        if retries < @max_retries
          Rails.logger.error "Failed to produce to #{topic}: #{e.message}. Retrying... (Attempt #{retries + 1}/#{max_retries})"
          retries += 1
        else
          Rails.logger.error "Failed to produce to #{topic} after #{@max_retries} attempts: #{e.message}"
          raise
        end
      end
    end
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
    api_key = request.headers['X-API-Key']
    unless api_key && api_key == ENV['INTER_SERVICE_API_KEY']
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
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
