class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale, :redirect_to_default_locale, :set_timezone
  after_action :set_locale_in_session

  helper_method :current_user, :locale

  @max_retries = 3

  def produce_with_retries(topic, payload)
    retries = 0

    loop do
      begin
        Karafka.producer.produce_sync(
          topic: topic,
          payload: payload,
          acks: :all
        )
        break
      rescue => e
        if retries < @max_retries
          Rails.logger.error "Failed to produce to #{topic}: #{e.message}. Retrying... (Attempt #{retries + 1}/#{@max_retries})"
          retries += 1
        else
          Rails.logger.error "Failed to produce to #{topic} after #{@max_retries} attempts: #{e.message}"
          raise
        end
      end
    end
  end

  def default_locale
    I18n.default_locale
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
    if request.path == '/' && params[:locale].blank? && session[:locale].blank?
      preferred_locale = I18n.default_locale
      redirect_to localized_redirect_path(preferred_locale)
    end
  end

  def set_timezone
    request_timezone = params[:time_zone] || request.headers['X-Timezone'] || 'Moscow'
    session[:time_zone] ||= request_timezone
    session_timezone = session[:time_zone]
    
    return unless current_user && current_user.time_zone != session_timezone
    
    current_user.update(time_zone: session_timezone)
  end

  def redirect_to_default_locale
    return if params[:locale].present? || request.path != '/'
    redirect_to "/#{I18n.default_locale}#{request.path}"
  end

  def current_user
    session[:user_data]
  end

  def api_request(endpoint, method: :get, params: {})
    response = HTTParty.send(
      method, 
      "#{ENV['AUTH_SERVICE_URL']}#{endpoint}",
      headers: { 
        'X-API-Key' => ENV['INTER_SERVICE_API_KEY'],
        'Content-Type' => 'application/json'
      },
      body: params.to_json
    )
  end

  private

  def localized_redirect_path(locale = nil)
    locale ||= I18n.locale
    "/#{locale}#{request.fullpath}"
  end
end
