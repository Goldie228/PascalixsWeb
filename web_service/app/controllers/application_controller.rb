class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :update_current_user, :set_locale,
                :redirect_to_default_locale, :set_timezone,
                :transfer_session_flash
  after_action :set_locale_in_session
  before_action do
    sid = request.cookie_jar["_auth_service_session"]
    Rails.logger.debug "RAW COOKIE SID: #{sid.inspect}"
    Rails.logger.debug "Parsed session[:user_id]: #{session[:user_id].inspect}"
  end

  before_action do
    Rails.logger.debug "Cookie Header: #{request.headers['Cookie']}"
  end


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

    Rails.logger.info session[:time_zone]

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
    Rails.logger.info "cookies: #{cookies.encrypted[:user_id]}"
    user_id = session[:user_id]

    unless user_id
      user_id = cookies.encrypted[:user_id]
      session[:user_id] = cookies.encrypted[:user_id]
      session[:two_factor_passed] = cookies.encrypted[:two_factor_passed]
    else
      cookies.encrypted[:user_id] = {
        value: user_id,
        expires: Time.at(2**31 - 1),
        path: "/",
        secure: Rails.env.production?,
        httponly: true
      }

      cookies.encrypted[:two_factor_passed] = {
        value: session[:two_factor_passed],
        expires: Time.at(2**31 - 1),
        path: "/",
        secure: Rails.env.production?,
        httponly: true
      }
    end

    unless user_id
      Rails.logger.info "Нет user_id"
      return nil
    end

    user_key = "user_updates:#{user_id}"
    user_data_hash = REDIS_CLIENT.hgetall(user_key)

    # 📡 Фолбэк на API, если Redis пустой
    if user_data_hash.blank?
      begin
        response = HTTParty.get(
          "http://#{ENV['HOST']}:3001/api/v1/users/#{user_id}",
          headers: {
            "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
          }
        )

        if response.code != 200
          Rails.logger.warn "⚠️ Не удалось получить пользователя из API: код #{response.code}"
          return nil
        end

        raw_data = response.parsed_response

        if raw_data.is_a?(Hash)
          timestamp = (Time.now.to_f * 1000).to_i.to_s
          user_data_hash = { timestamp => raw_data.to_json }
          Rails.logger.debug "📥 Данные из API обёрнуты в формат Redis"
        else
          Rails.logger.warn "⚠️ API вернул невалидную структуру"
          return nil
        end
      rescue => e
        Rails.logger.error "❌ Ошибка HTTP-запроса: #{e.message}"
        return nil
      end
    end

    # 📦 Извлечение самой свежей записи
    numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }

    if numeric_keys.present?
      latest_timestamp = numeric_keys.map(&:to_i).max.to_s
      raw_json = user_data_hash[latest_timestamp]
      Rails.logger.debug "✅ Используем метку: #{latest_timestamp}"
    else
      raw_json = user_data_hash.values.first
      Rails.logger.warn "⚠️ Нет меток времени — используем первое значение"
    end

    # 🔍 Парсим JSON
    user_data = begin
      parsed = JSON.parse(raw_json)
      parsed.is_a?(Hash) ? parsed : {}
    rescue => e
      Rails.logger.error "❌ Ошибка парсинга JSON: #{e.message}"
      {}
    end

    Rails.logger.debug "📦 user_data: #{user_data.inspect}"

    # Даже если user_data пустой, создадим объект пользователя
    # Извлечение Discord Account

    if user_data
      discord_account = nil
      if user_data["discord_account"].is_a?(Hash)
        discord_payload = user_data["discord_account"]

        discord_avatar = AvatarUrlResolver.resolve(
          url: discord_payload["avatar"],
          fallback_url: view_context.image_url("steve.webp")
        )

        discord_account = OpenStruct.new(
          id:             discord_payload["id"],
          user_id:        discord_payload["user_id"],
          discord_id:     discord_payload["discord_id"],
          username:       discord_payload["username"],
          discriminator:  discord_payload["discriminator"],
          email:          discord_payload["email"],
          avatar:         discord_avatar
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

  def is_banned?(punishments)
    punishments.any? do |p|
      p[:type].to_s.downcase == "ban" && punishment_active?(p)
    end
  end

  def is_muted?(punishments)
    punishments.any? do |p|
      p[:type].to_s.downcase == "mute" && punishment_active?(p)
    end
  end

  def punishment_active?(p)
    return false unless p[:issued_at_raw].present?
    return false if p[:status].present? && p[:status] == I18n.t('admin.players.punishments.status.expired')

    expires = begin
                Time.parse(p[:expires_at]) unless p[:expires_at] == "—"
              rescue
                nil
              end

    expires.nil? || Time.current < expires
  end

  def not_expired?(expires_at)
    return true unless expires_at.present?
    Time.current < Time.iso8601(expires_at) rescue false
  end

  def fetch_punishments(minecraft_nick)
    punishments_key   = "punishment_history:#{minecraft_nick}"
    punishments_json  = REDIS_CLIENT.get(punishments_key)

    unless punishments_json.present?
      Rails.logger.info "📡 Нет данных о наказаниях в Redis. Запрос к API: punishment_history"
      response = HTTParty.get(
        "http://#{ENV['HOST']}:3001/api/v1/players/#{minecraft_nick}/punishments",
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
        }
      )
      if response.success?
        begin
          test_parse = JSON.parse(response.body)
          punishments_json = response.body
        rescue JSON::ParserError => e
          Rails.logger.error "❌ Ошибка парсинга JSON punishments: #{e.message}"
        end
      end
    end

    return [] unless punishments_json.present?

    punishments = punishments_json.present? ? JSON.parse(punishments_json, symbolize_names: true) : []
    time_zone   = session[:time_zone] || "UTC"
    now         = Time.current

    punishments = punishments.map do |p|
      issued    = p[:issued_at] && Time.parse(p[:issued_at].to_s)
      expires   = p[:expires_at] && Time.parse(p[:expires_at].to_s)
      is_active = p[:status] && (expires.nil? || now < expires)

      {
        id: p[:id],
        type: p[:type],
        reason: p[:reason],
        price: p[:price],
        issued_at: issued.in_time_zone(time_zone).strftime("%d.%m.%Y %H:%M:%S"),
        expires_at: expires ? expires.in_time_zone(time_zone).strftime("%d.%m.%Y %H:%M:%S") : "—",
        status: is_active ? I18n.t('admin.players.punishments.status.active') : I18n.t('admin.players.punishments.status.expired'),
        issued_at_raw: issued
      }
    end

    punishments
  rescue JSON::ParserError => e
    Rails.logger.error "Ошибка парсинга наказаний для #{user_id}: #{e.message}"
    []
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
