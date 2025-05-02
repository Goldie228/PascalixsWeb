class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :clean_session, :update_current_user, :set_locale, :redirect_to_default_locale, :set_timezone, :transfer_session_flash, :log_cookies
  after_action :set_locale_in_session, :drop_session_flash, :clean_session

  helper_method :current_user, :locale

  MAX_RETRIES = 3

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
    
    update_user_time_zone(session_timezone)
  end

  def redirect_to_default_locale
    return if params[:locale].present? || request.path != '/'
    redirect_to "/#{I18n.default_locale}#{request.path}"
  end

  def current_user
    @current_user
  end

  def clean_session
    allowed_keys = [:user_id, :_csrf_token, :locale, :notice, :alert, :errors]
    session.keys.each do |key|
      session.delete(key) unless allowed_keys.include?(key.to_sym)
    end
  end
  
  
  def update_current_user(redis_client: Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')))
    Rails.logger.info "Начало метода update_current_user."
  
    user_id = session[:user_id]
    unless user_id
      Rails.logger.warn "Сессия не содержит user_id. Пользователь не авторизован."
      return nil
    end
  
    user_key = "user_updates:#{user_id}"
    Rails.logger.info "Запрос данных пользователя из Redis для user_id: #{user_id}, ключ: #{user_key}"
  
    # Получаем хэш, где ключами служат timestamp-ы
    user_data_hash = redis_client.hgetall(user_key)
  
    if user_data_hash.blank?
      Rails.logger.info "Данных в Redis не найдено для #{user_key}. Выполняется API-запрос."
      begin
        produce_with_retries("auth_service_get_user", { user_id: user_id })
      rescue => e
        Rails.logger.error "Ошибка при API-запросе для user_id #{user_id}: #{e.message}"
        return nil
      end
    else
      Rails.logger.info "Данные пользователя успешно получены из Redis для #{user_key}."
  
      # Фильтруем ключи, оставляя только числовые (состоящие только из цифр)
      numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
      if numeric_keys.empty?
        Rails.logger.warn "Не обнаружены числовые ключи для обновлений пользователя в #{user_key}"
        return nil
      end

      latest_timestamp = numeric_keys.map(&:to_i).max.to_s
      json_string = user_data_hash[latest_timestamp]
      Rails.logger.debug "Выбрано обновление с меткой времени #{latest_timestamp}"
      event = JSON.parse(json_string) rescue {}
      # Предполагается, что полезные данные находятся в ключе "data"
      user_data = event["data"] || {}
    end

    # Discord Account extraction from user_data["discord_account"]
    if user_data
      discord_account = nil
      if user_data["discord_account"].present?
        discord_payload = user_data["discord_account"]
        discord_account = OpenStruct.new(
          id:             discord_payload["id"],
          user_id:        discord_payload["user_id"],
          discord_id:     discord_payload["discord_id"],
          username:       discord_payload["username"],
          discriminator:  discord_payload["discriminator"],
          email:          discord_payload["email"],
          avatar:         discord_payload["avatar"]
        )
      end
    
      # Minecraft Account extraction from user_data["minecraft_account"]
      minecraft_account = nil
      if user_data["minecraft_account"].present?
        minecraft_payload = user_data["minecraft_account"]
        minecraft_account = OpenStruct.new(
          id:             minecraft_payload["id"],
          user_id:        minecraft_payload["user_id"],
          nickname:       minecraft_payload["nickname"],
          password_hash:  minecraft_payload["password_hash"]
        )
      end
    
      # Собираем общий объект пользователя, объединяя основные данные и связанные аккаунты
        @current_user = OpenStruct.new(
          { id: user_id }
            .merge(user_data&.symbolize_keys)
            .merge(discord_account: discord_account, minecraft_account: minecraft_account)
        )
    end
  
    Rails.logger.info "Пользовательский объект создан: #{@current_user.inspect}"
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
  rescue HTTParty::Error => e
    Rails.logger.error "Ошибка API-запроса (#{method} #{endpoint}): #{e.message}"
    raise
  rescue StandardError => e
    Rails.logger.error "Общая ошибка API-запроса (#{method} #{endpoint}): #{e.message}"
    raise
  end

  private

  def update_user_time_zone(new_timezone, redis_client: Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')))
    user_key = "user:#{current_user.id}"
    redis_client.hset(user_key, :time_zone, new_timezone)
    Rails.logger.info "Обновление таймзоны для пользователя #{current_user.id}: #{new_timezone}"
  end

  def decode_token(token)
    JWT.decode(token, ENV['AUTH_SECRET'], true, algorithm: 'HS256').first
  rescue JWT::DecodeError => e
    Rails.logger.error "Ошибка при декодировании токена: #{e.message}"
    nil
  end

  def valid_payload?(payload)
    payload && Time.current < Time.at(payload['exp'])
  end

  def localized_redirect_path(locale = nil)
    locale ||= I18n.locale
    "/#{locale}#{request.fullpath}"
  end

  def log_cookies
    Rails.logger.info "Session before transfer: #{session.inspect}"
    Rails.logger.info "Received cookies: #{request.cookies.inspect}"
  end

  def transfer_session_flash
    Rails.logger.info "Session flash: #{session[:alert]}"
    Rails.logger.info "Session flash: #{session[:notice]}"

    flash[:alert]  = session[:alert]  if session[:alert].present?
    flash[:notice] = session[:notice] if session[:notice].present?
  end

  def auth_payload_valid?
    @auth_payload.present? && 
    @auth_payload[:user_id].present? && 
    Time.current < Time.at(@auth_payload[:exp])
  end

  def drop_session_flash
    session[:alert]  = nil
    session[:notice] = nil

    flash[:alert]  = nil
    flash[:notice] = nil
  end
end
