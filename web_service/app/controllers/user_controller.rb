DiscordStruct = Struct.new(:id, :user_id, :discord_id, :username, :discriminator, :avatar, keyword_init: true)
MinecraftStruct = Struct.new(:id, :user_id, :nickname, keyword_init: true)

UserStruct = Struct.new(
  :id, :user_id, :nickname, :is_added, :about_me,
  :youtube_url, :twitch_url, :tiktok_url,
  :youtube_channel_name, :twitch_channel_name, :tiktok_channel_name,
  :role_name, :role_color,
  :is_banned, :mc_roles,
  :discord_account, :minecraft_account,
  keyword_init: true
)


class UserController < ApplicationController
  before_action :require_login, :update_users_data

  def show
    require_login

    @nickname = nil
    @player = current_user
    @edit = true

    user_id = @player.id

    if @player.minecraft_account&.present?
      @nickname = @player.minecraft_account.nickname
      Rails.logger.debug "Получен Minecraft ник: #{@nickname}"

      unless REDIS_CLIENT.hget("punishments:#{user_id}", "data").present?
        produce_with_retries(
          "get_user_punishments",
          { user_id: user_id }
        )
      end

       McOnlineStatusJob.perform_later(nickname: @nickname, user_id: user_id)
    end

    @is_banned = is_banned?(user_id)

    if @nickname.present?
      redis_key = "player_roles:#{@nickname}"

      redis_data = REDIS_CLIENT.get(redis_key)

      unless redis_data.present?
        produce_with_retries("minecraft_service_get_roles", payload: { nickname: @nickname })

        max_attempts = 3
        attempt = 0
        redis_data = nil

        while attempt < max_attempts
          sleep 1
          redis_data = REDIS_CLIENT.get(redis_key)
          break if redis_data.present?
          attempt += 1
        end
      end

      if redis_data.present?
        roles_hash = JSON.parse(redis_data)
        @mc_roles = roles_hash.transform_keys { |k| k.to_i }
        Rails.logger.debug "Получены данные ролей из Redis: #{@mc_roles.inspect}"
      else
        @mc_roles = {}
        Rails.logger.info("Данные ролей для #{@nickname} не найдены в Redis после #{max_attempts} попыток")
      end
    else
      @mc_roles = {}
      Rails.logger.info("Не задан nickname, поэтому роли не запрашиваются")
    end

    @web_role = @player.role_name
    @web_role_color = @player.role_color
  end

  def public_profile
    require_login
    nickname = params[:nickname].to_s.strip

    if nickname.blank?
      redirect_to localized_root_path and return
    end

    redis_key = "public_profile:#{nickname}"
    cached_data = REDIS_CLIENT.get(redis_key)

    if cached_data.present?
      profile = JSON.parse(cached_data, symbolize_names: true)
    else
      response = HTTParty.get(
        "http://#{ENV["HOST"]}:3001/api/v1/players/#{nickname}",
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
        }
      )

      unless response.success?
        redirect_to localized_root_path and return
      end

      profile = response.parsed_response.deep_symbolize_keys
    end

    roles_key = "player_roles:#{nickname}"
    roles_data = REDIS_CLIENT.get(roles_key)
    roles_hash = roles_data.present? ? JSON.parse(roles_data).transform_keys(&:to_i) : {}

    safe_data = profile.slice(
      :id, :user_id, :nickname, :is_added, :about_me,
      :youtube_url, :twitch_url, :tiktok_url,
      :youtube_channel_name, :twitch_channel_name, :tiktok_channel_name,
      :role_name, :role_color
    )

    discord_payload = profile[:discord_account]
    discord_payload = discord_payload.is_a?(OpenStruct) ? discord_payload.to_h : discord_payload

    discord_data = discord_payload[:table].deep_symbolize_keys.except(:email) if discord_payload[:table].present?
    discord_account = discord_data ? DiscordStruct.new(**discord_data) : DiscordStruct.new

    minecraft_payload = profile[:minecraft_account]
    minecraft_payload = minecraft_payload.is_a?(OpenStruct) ? minecraft_payload.to_h : minecraft_payload

    minecraft_data = minecraft_payload[:table].deep_symbolize_keys.except(:password_hash) if minecraft_payload[:table].present?
    minecraft_account = minecraft_data ? MinecraftStruct.new(**minecraft_data) : MinecraftStruct.new

    @player = UserStruct.new(
      **safe_data,
      discord_account:  discord_account,
      minecraft_account: minecraft_account,
      mc_roles: roles_hash,
      is_banned: is_banned?(safe_data[:user_id])
    )

    if (current_user.role_name == "DEV" || current_user.role_name == "OWNER") || current_user.id == @player.id
      @edit = true
    else
      @edit = false
    end

    user_id = @player.id

    if @player.minecraft_account&.present?
      @nickname = @player.minecraft_account.nickname
      Rails.logger.debug "Получен Minecraft ник: #{@nickname}"

      unless REDIS_CLIENT.hget("punishments:#{user_id}", "data").present?
        produce_with_retries(
          "get_user_punishments",
          { user_id: user_id }
        )
      end

       McOnlineStatusJob.perform_later(nickname: @nickname, user_id: user_id)
    end

    @is_banned = is_banned?(user_id)

    if @nickname.present?
      redis_key = "player_roles:#{@nickname}"

      redis_data = REDIS_CLIENT.get(redis_key)

      unless redis_data.present?
        produce_with_retries("minecraft_service_get_roles", payload: { nickname: @nickname })

        max_attempts = 3
        attempt = 0
        redis_data = nil

        while attempt < max_attempts
          sleep 1
          redis_data = REDIS_CLIENT.get(redis_key)
          break if redis_data.present?
          attempt += 1
        end
      end

      if redis_data.present?
        roles_hash = JSON.parse(redis_data)
        @mc_roles = roles_hash.transform_keys { |k| k.to_i }
        Rails.logger.debug "Получены данные ролей из Redis: #{@mc_roles.inspect}"
      else
        @mc_roles = {}
        Rails.logger.info("Данные ролей для #{@nickname} не найдены в Redis после #{max_attempts} попыток")
      end
    else
      @mc_roles = {}
      Rails.logger.info("Не задан nickname, поэтому роли не запрашиваются")
    end

    @web_role = @player.role_name
    @web_role_color = @player.role_color

    render "user/show", locals: { current_user: @player, mc_roles: @mc_roles }
  end

  def players
    filters   = Array(params[:filters])
    per_page  = (params[:per_page] || 25).to_i.clamp(1, 100)
    page      = (params[:page] || 1).to_i.clamp(1, 10_000)
    order     = %w[asc desc].include?(params[:order]) ? params[:order] : "asc"
    sort      = %w[minecraft_nickname discord_username].include?(params[:sort]) ? params[:sort] : "minecraft_nickname"
    search    = params[:search].to_s.strip.downcase

    # Основной запрос без пагинации
    sql = <<~SQL
      SELECT user_id, discord_username, minecraft_nickname, discord_avatar_url, role_id, punishment_status
      FROM users
      WHERE role_id != 1
      ORDER BY #{sort} #{order}
    SQL

    raw_players = ClickHouse.connection.select_all(sql)

    # Обработка и фильтрация игроков
    @players = raw_players.map do |player|
      nickname   = player["minecraft_nickname"].to_s
      is_online  = REDIS_CLIENT.get("player_online:#{nickname}").present?
      is_banned  = player["punishment_status"].to_i == 3
      status     = is_banned ? "ban" : (is_online ? "online" : "offline")

      raw_roles_json = REDIS_CLIENT.get("player_roles:#{nickname}")
      roles_hash = raw_roles_json.present? ? JSON.parse(raw_roles_json) : {}
      heavy_role = roles_hash.max_by { |weight_str, _| weight_str.to_i }&.last || {}

      role_weight = roles_hash.keys.map(&:to_i).max || 0

      player.merge(
        "status"        => status,
        "role_name"     => heavy_role["name"],
        "role_color"    => heavy_role["color"],
        "role_weight"   => role_weight,
        "role_system"   => heavy_role["system_name"]
      )
    end.select do |player|
      status_filters = filters & %w[online offline]
      status_match = status_filters.blank? || status_filters.include?(player["status"])

      search_match = search.blank? || begin
        term = search.downcase
        [
          player["minecraft_nickname"].to_s,
          player["discord_username"].to_s,
          player["role_name"].to_s
        ].any? { |val| val.downcase.include?(term) }
      end

      status_match && search_match
    end.sort_by! { |player| player["role_weight"].to_i * (order == "asc" ? 1 : -1) }

    # Пагинация после всех фильтраций
    @total_count = @players.size
    @total_pages = [ (@total_count / per_page.to_f).ceil, 1 ].max
    page         = page > @total_pages ? 1 : page

    @page     = page
    @per_page = per_page
    offset    = (page - 1) * per_page

    @players = @players[offset, per_page] || []

    @players
  end

  def update_about_me
    about_me = params[:about_me_text]
    user_id = current_user.id

    if about_me.present? && current_user.present?
      produce_with_retries(
        "auth_service_set_about_me",
        payload: {
          user_id: user_id,
          about_me: about_me
        }
      )
    end

    attempts = 0
    user_key = "user_updates:#{user_id}"

    while attempts < 30
      begin
        sleep 0.5
        user_data_hash = REDIS_CLIENT.hgetall(user_key)

        if user_data_hash.blank?
          next
        end

        numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
        next if numeric_keys.empty?

        latest_timestamp = numeric_keys.map(&:to_i).max.to_s
        json_string = user_data_hash[latest_timestamp]

        event = JSON.parse(json_string) rescue {}
        user_data = event || {}

        break if user_data["about_me"] == about_me

        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    redirect_to user_profile_path
  end

  def youtube_unbind
    user_id = current_user.id

    if current_user.present?
      produce_with_retries(
        "auth_service_youtube_unbind",
        payload: {
          user_id: user_id
        }
      )
    else
      return
    end

    attempts = 0
    user_key = "user_updates:#{user_id}"

    while attempts < 30
      begin
        sleep 0.5
        user_data_hash = REDIS_CLIENT.hgetall(user_key)

        if user_data_hash.blank?
          next
        end

        numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
        next if numeric_keys.empty?

        latest_timestamp = numeric_keys.map(&:to_i).max.to_s
        json_string = user_data_hash[latest_timestamp]

        event = JSON.parse(json_string) rescue {}
        user_data = event || {}

        break if !user_data["youtube_channel_name"].present?

        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    sleep 1

    redirect_to user_profile_path
  end

  def tiktok_unbind
    user_id = current_user.id

    if current_user.present?
      produce_with_retries(
        "auth_service_tiktok_unbind",
        payload: {
          user_id: user_id
        }
      )
    else
      return
    end

    attempts = 0
    user_key = "user_updates:#{user_id}"

    while attempts < 30
      begin
        sleep 0.5
        user_data_hash = REDIS_CLIENT.hgetall(user_key)

        if user_data_hash.blank?
          next
        end

        numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
        next if numeric_keys.empty?

        latest_timestamp = numeric_keys.map(&:to_i).max.to_s
        json_string = user_data_hash[latest_timestamp]

        event = JSON.parse(json_string) rescue {}
        user_data = event || {}

        break if !user_data["tiktok_channel_name"].present?

        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    sleep 1

    redirect_to user_profile_path
  end

  def twitch_unbind
    user_id = current_user.id

    if current_user.present?
      produce_with_retries(
        "auth_service_twitch_unbind",
        payload: {
          user_id: user_id
        }
      )
    else
      return
    end

    attempts = 0
    user_key = "user_updates:#{user_id}"

    while attempts < 30
      begin
        sleep 0.5
        user_data_hash = REDIS_CLIENT.hgetall(user_key)

        if user_data_hash.blank?
          next
        end

        numeric_keys = user_data_hash.keys.select { |k| k.match?(/\A\d+\z/) }
        next if numeric_keys.empty?

        latest_timestamp = numeric_keys.map(&:to_i).max.to_s
        json_string = user_data_hash[latest_timestamp]

        event = JSON.parse(json_string) rescue {}
        user_data = event || {}

        break if !user_data["twitch_channel_name"].present?

        attempts += 1
      rescue => e
        Rails.logger.error "Ошибка запроса данных: #{e.message}"
        return nil
      end
    end

    sleep 1

    redirect_to user_profile_path
  end

  def account
  end

  def delete_account
    if current_user.minecraft_account.present?
      # Отнимаем проходку
      payload = {
        nickname: current_user.minecraft_account.nickname,
        pass: false,
        password: nil
      }
      produce_with_retries("change_pass_status", payload.to_json)
    end

    nickname = current_user.minecraft_account&.nickname
    discord_id = current_user.discord_account&.discord_id

    payload = {}
    payload[:discord_id] = discord_id if discord_id.present?
    payload[:nickname] = nickname if nickname.present?

    if payload.empty?
      Rails.logger.warn "[DeletePlayer] Ни nickname, ни discord_id не найдены у пользователя #{current_user.id}"
      return
    end

    produce_with_retries("delete_player", payload.to_json)

    cookies.to_hash.each_key do |key|
      cookies.delete(key)
    end

    reset_session

    cookies.encrypted[:goodbye] = {
      value: true,
      expires: Time.at(2**31 - 1),
      path: "/",
      secure: Rails.env.production?,
      httponly: true
    }

    render json: { success: true, message: I18n.t("admin.players.notifications.account_deleted") }
  end

  def change_email
  end

  def change_email_process
    # Получаем параметры
    new_email = params[:email].to_s.strip
    password = params[:password].to_s.strip
    nickname = current_user.minecraft_account.nickname

    # Базовая валидация
    if new_email.blank? || password.blank?
      return render json: { 
        success: false, 
        message: t('account.change_email.errors.all_fields_required') 
      }, status: :unprocessable_entity
    end

    if new_email == current_user.discord_account.email
      return render json: { 
        success: false, 
        message: t('account.change_email.errors.email_repeat') 
      }, status: :unprocessable_entity
    end

    unless URI::MailTo::EMAIL_REGEXP.match?(new_email)
      return render json: { 
        success: false, 
        message: t('account.change_email.errors.invalid_email') 
      }, status: :unprocessable_entity
    end

    begin
      # 1. Проверка пароля
      password_check_response = HTTParty.get(
        "http://#{ENV["HOST"]}:3001/api/v1/players/#{nickname}/password_check",
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
          "X-Password" => password,
          "Accept-Language" => I18n.locale.to_s # Добавляем язык в заголовок
        },
        timeout: 5
      )

      unless password_check_response.success?
        error_message = password_check_response['message'] || t('account.change_email.errors.invalid_password')
        return render json: {
          success: false,
          message: error_message
        }, status: :unauthorized
      end

      token = SecureRandom.hex(32)

      payload = {
        new_email: new_email,
        user_id: current_user.id
      }

      REDIS_CLIENT.set("token:#{token}", payload.to_json, ex: 30.minutes.to_i)

      payload = {
        token: token,
        email: new_email,
        nickname: current_user&.minecraft_account&.nickname || current_user&.discord_username&.username,
        locale: I18n.locale,
        time_zone: session[:time_zone] || "UTC"
      }

      produce_with_retries("send_check_email", payload.to_json)

      session[:send_email] = true
      session[:new_email] = new_email
      render json: { redirect_to: pending_email_verification_path }
    rescue HTTParty::Error => e
      render json: {
        success: false,
        message: t('account.change_email.errors.connection_error', error: e.message)
      }, status: :service_unavailable
    rescue Timeout::Error
      render json: {
        success: false,
        message: t('account.change_email.errors.timeout_error')
      }, status: :gateway_timeout
    rescue => e
      Rails.logger.error "Email change error: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: {
        success: false,
        message: t('account.change_email.errors.unknown_error')
      }, status: :internal_server_error
    end
  end

  private

  def is_banned?(user_id)
    punishments = fetch_punishments(user_id)
    punishments.any? { |p| p["type"].to_s.downcase == "ban" }
  end

  def fetch_punishments(user_id)
    punishments_json = REDIS_CLIENT.hget("punishments:#{user_id}", "data")
    return [] unless punishments_json.present?

    JSON.parse(punishments_json)
  rescue JSON::ParserError => e
    Rails.logger.error "Ошибка парсинга наказаний для #{user_id}: #{e.message}"
    []
  end

  def require_login
    unless current_user
      redirect_to login_path, alert: t("controllers.auth.unauthorized")
    end
  end

  def update_users_data
    @result = ClickHouse.connection.select_all("SELECT count() AS cnt FROM users")
    count  = @result.first["cnt"].to_i
    Rails.logger.info "[Admin] Начальное количество записей в ClickHouse: #{count}"
    ready = 0

    if count.zero?
      produce_with_retries("update_users_data", payload: {})

      10.times do
        sleep 0.5
        @result = ClickHouse.connection.select_all("SELECT count() AS cnt FROM users")
        ready = @result.first["cnt"].to_i
        Rails.logger.info "[Admin] Попытка синхронизации ClickHouse — найдено записей: #{ready}"
        break if ready > 0
      end
    else
      ready = count
    end

    if ready == 0
      Rails.logger.error "[Admin] Не удалось получить данные из ClickHouse после синхронизации"
      session[:alert] = "Ошибка получения информации о пользователях"
      redirect_to localized_root_path
    else
      Rails.logger.info "[Admin] Данные ClickHouse готовы, всего записей: #{ready}"
    end
  end
end
