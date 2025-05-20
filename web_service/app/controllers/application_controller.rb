class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :update_current_user, :set_locale,
                :redirect_to_default_locale, :set_timezone,
                :transfer_session_flash
  after_action :set_locale_in_session

  helper_method :current_user, :locale

  MAX_RETRIES = 10
  RETRY_DELAY = 0.5

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

  def set_timezone
    request_timezone = params[:time_zone] || request.headers["X-Timezone"] || "Moscow"
    session[:time_zone] ||= request_timezone
    session_timezone = session[:time_zone]

    return unless current_user && current_user.time_zone != session_timezone

    update_user_time_zone(session_timezone)
  end

  def redirect_to_default_locale
    return if params[:locale].present? || request.path != "/"
    redirect_to "/#{I18n.default_locale}#{request.path}"
  end

  def current_user
    if session[:two_factor_passed]
      @current_user
    end
  end

  def update_current_user
    Rails.logger.info "cookies: #{cookies[:user_id]}"
    user_id = session[:user_id]

    unless user_id
      user_id = cookies[:user_id]
      session[:user_id] = cookies[:user_id]
      session[:two_factor_passed] = cookies[:two_factor_passed]
    else
      cookies[:user_id] = {
        value: user_id,
        expires: Time.at(2**31 - 1),
        path: "/",
        secure: false,
        httponly: false
      }

      cookies[:two_factor_passed] = {
        value: session[:two_factor_passed],
        expires: Time.at(2**31 - 1),
        path: "/",
        secure: false,
        httponly: false
      }
    end

    unless user_id
      Rails.logger.info "Нет user_id"
      return nil
    end

    user_key = "user_updates:#{user_id}"

    user_data_hash = nil
    attempts = 0

    while user_data_hash.blank? && user_id.present? && attempts < MAX_RETRIES
      begin
        produce_with_retries("auth_service_get_user", { user_id: user_id })
        sleep RETRY_DELAY
        user_data_hash = REDIS_CLIENT.hgetall(user_key)
        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    if user_data_hash.blank?
      return nil # Если после всех попыток данных нет, возвращаем nil
    end

    # Фильтруем ключи, оставляя только числовые (timestamp)
    numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
    return nil if numeric_keys.empty?

    latest_timestamp = numeric_keys.map(&:to_i).max.to_s
    json_string = user_data_hash[latest_timestamp]
    Rails.logger.debug "Выбрано обновление с меткой времени #{latest_timestamp}"

    event = JSON.parse(json_string) rescue {}
    user_data = event || {}

    # Даже если user_data пустой, создадим объект пользователя
    # Извлечение Discord Account

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

      # Извлечение Minecraft Account
      minecraft_account = nil
      if user_data["minecraft_account"].present? && user_data["minecraft_account"].any?
        minecraft_payload = user_data["minecraft_account"]
        minecraft_account = OpenStruct.new(
          id:             minecraft_payload["id"],
          user_id:        minecraft_payload["user_id"],
          nickname:       minecraft_payload["nickname"],
          password_hash:  minecraft_payload["password_hash"]
        )
      end

      Rails.logger.info "Пользовательский объект создан: #{minecraft_account}"

      minecraft_account ||= {}

      @current_user = OpenStruct.new(
        { id: user_id }
          .merge(user_data.symbolize_keys)
          .merge(discord_account: discord_account, minecraft_account: minecraft_account)
      )

      Rails.logger.info "Пользовательский объект создан: #{@current_user.inspect}"
    end
  end

  private

  def update_user_time_zone(new_timezone)
    user_key = "user:#{current_user.id}"
    REDIS_CLIENT.hset(user_key, :time_zone, new_timezone)
  end

  def localized_redirect_path(locale = nil)
    locale ||= I18n.locale
    "/#{locale}#{request.fullpath}"
  end

  def transfer_session_flash
    Rails.logger.info "Session flash: #{session[:alert]}"
    Rails.logger.info "Session flash: #{session[:notice]}"

    flash.now[:alert]  = session.delete(:alert)  if session[:alert].present?
    flash.now[:notice] = session.delete(:notice) if session[:notice].present?
  end
end
