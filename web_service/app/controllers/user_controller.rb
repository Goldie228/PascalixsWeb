DiscordStruct = Struct.new(:id, :user_id, :discord_id, :username, :discriminator, :avatar, keyword_init: true)
MinecraftStruct = Struct.new(:id, :user_id, :nickname, keyword_init: true)

UserStruct = Struct.new(
  :id, :user_id, :nickname, :is_added, :about_me,
  :youtube_url, :twitch_url, :tiktok_url,
  :youtube_channel_name, :twitch_channel_name, :tiktok_channel_name,
  :role_name, :role_color,
  :is_banned, :mc_roles,
  :is_sponsor,
  :discord_account, :minecraft_account,
  keyword_init: true
)

require 'rest-client'

class UserController < ApplicationController
  before_action :require_login, except: [ :reset_password, :validate_new_password ]
  before_action :update_users_data

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

    if @nickname.present?
      @punishments = fetch_punishments(@nickname) || nil
      if @punishments
        @is_banned = is_banned?(@punishments)
        @is_muted = is_muted?(@punishments)
      end
    end

    if @nickname.present?
      redis_key = "player_roles:#{@nickname}"
      redis_data = REDIS_CLIENT.get(redis_key)

      if redis_data.present?
        roles_hash = JSON.parse(redis_data)
        @mc_roles = roles_hash.transform_keys { |k| k.to_i }
        Rails.logger.debug "Получены данные ролей из Redis: #{@mc_roles.inspect}"
      else
        @mc_roles = {}
      end
    else
      @mc_roles = {}
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
      :role_name, :role_color, :is_sponsor
    )

    discord_payload = profile[:discord_account]
    discord_payload = discord_payload.is_a?(OpenStruct) ? discord_payload.to_h : discord_payload

    discord_data = discord_payload[:table].deep_symbolize_keys.except(:email) if discord_payload[:table].present?
    discord_account = discord_data ? DiscordStruct.new(**discord_data) : DiscordStruct.new

    if discord_account
      discord_account.avatar = AvatarUrlResolver.resolve(
        url: discord_account.avatar,
        fallback_url: view_context.image_url("steve.webp")
      )
    end

    minecraft_payload = profile[:minecraft_account]
    minecraft_payload = minecraft_payload.is_a?(OpenStruct) ? minecraft_payload.to_h : minecraft_payload

    minecraft_data = minecraft_payload[:table].deep_symbolize_keys.except(:password_hash) if minecraft_payload[:table].present?
    minecraft_account = minecraft_data ? MinecraftStruct.new(**minecraft_data) : MinecraftStruct.new

    if nickname.present?
      @punishments = fetch_punishments(nickname) || nil
      if @punishments.present?
        @is_banned = is_banned?(@punishments)
        @is_muted = is_muted?(@punishments)
      end
    end

    if current_user.minecraft_account.nickname.present?
      user_punishments = fetch_punishments(current_user.minecraft_account.nickname)
      if user_punishments.present?
        @user_is_banned = is_banned?(user_punishments)
        @user_is_muted = is_muted?(user_punishments)
      end
    end

    @player = UserStruct.new(
      **safe_data,
      discord_account:  discord_account,
      minecraft_account: minecraft_account,
      mc_roles: roles_hash,
      is_banned: @punishments.present? ? is_banned?(@punishments) : false
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

    if @nickname.present?
      redis_key = "player_roles:#{@nickname}"
      redis_data = REDIS_CLIENT.get(redis_key)

      if redis_data.present?
        roles_hash = JSON.parse(redis_data)
        @mc_roles = roles_hash.transform_keys { |k| k.to_i }
      else
        @mc_roles = {}
      end
    else
      @mc_roles = {}
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
      SELECT user_id, discord_username, minecraft_nickname, discord_avatar_url,
       role_id, punishment_status, is_sponsor, has_youtube, has_twitch, has_tiktok
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

      player["discord_avatar_url"] = AvatarUrlResolver.resolve(
        url: player["discord_avatar_url"],
        fallback_url: view_context.image_url("steve.webp")
      )

      player.merge(
        "status"       => status,
        "role_name"    => heavy_role["name"],
        "role_color"   => heavy_role["color"],
        "role_weight"  => role_weight,
        "role_system"  => heavy_role["system_name"],
        "is_sponsor"   => player["is_sponsor"].to_i == 1,
        "has_youtube"  => player["has_youtube"].to_i == 1,
        "has_twitch"   => player["has_twitch"].to_i == 1,
        "has_tiktok"   => player["has_tiktok"].to_i == 1
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
    user_id = params[:user_id]

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
          "Accept-Language" => I18n.locale.to_s
        }
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

      REDIS_CLIENT.set("token:#{token}", payload.to_json, ex: 2.hours.to_i)

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

  def prepare_password_reset
    session[:password_reset_pending] = true
    redirect_to pending_password_reset_path
  end

  def reset_password
    token = params[:token].to_s.strip

    if token.blank?
      redirect_to localized_root_path and return
    end

    @login_mode = REDIS_CLIENT.get("login_token:#{token}").present?
    session[:login_mode] = @login_mode

    redis_key   = @login_mode ? "login_token:#{token}" : "token_pass:#{token}"

    redis_data = REDIS_CLIENT.get(redis_key)
    user_id = redis_data.present? ? JSON.parse(redis_data)["user_id"] : nil

    unless @login_mode
      # Обычный режим: current_user должен совпадать с токеном
      if current_user.nil? || current_user.id.to_s != user_id
        redirect_to localized_root_path and return
      end
    end

    if user_id.blank?
      redirect_to localized_root_path and return
    end

    if @login_mode && !current_user
      session[:user_id] = user_id
      session[:two_factor_passed] = true
      update_current_user
    end

    if current_user.nil? || current_user.id.to_s != user_id
      redirect_to localized_root_path and return
    end

    session[:password_reset_key] = redis_key
  end

  def validate_new_password
    I18n.locale = request.headers['X-Locale'].presence || I18n.default_locale

    @login_mode = session[:login_mode]

    unless @login_mode
      current        = params[:current_password]
    end
    new_password     = params[:new_password]
    confirm_password = params[:password_confirmation]

    errors = {}

    # 1. Базовая валидация
    unless @login_mode
      errors[:current_password] = t('change_password.errors.current_password.blank') if current.blank?
    end

    errors[:new_password] = t('change_password.errors.new_password.blank') if new_password.blank?

    unless @login_mode
      errors[:new_password] = t('change_password.errors.new_password.same_as_old') if current == new_password
    end

    errors[:password_confirmation] = t('change_password.errors.password_confirmation.blank') if confirm_password.blank?

    if new_password.present? && confirm_password.present? && new_password != confirm_password
      errors[:password_confirmation] = t('change_password.errors.passwords_do_not_match')
    end

    # Возвращаем ошибки, если есть
    if errors.any?
      render "validate_new_password", formats: :json, status: :unprocessable_entity, locals: { errors: errors }
      return
    end

    # 2. Проверка текущего пароля
    nickname = current_user.minecraft_account.nickname

    unless @login_mode
      password_check_response = HTTParty.get(
        "http://#{ENV["HOST"]}:3001/api/v1/players/#{nickname}/password_check",
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
          "X-Password" => current,
          "Accept-Language" => I18n.locale.to_s
        },
        timeout: 5
      )

      unless password_check_response.success?
        errors[:current_password] = t('change_password.errors.current_password.invalid')
        render "validate_new_password", formats: :json, status: :unprocessable_entity, locals: { errors: errors }
        return
      end
    end

    # 3. Проверка валидации нового пароля
    # Локаль уже установлена в начале метода
    response = HTTParty.post(
      "http://#{ENV['HOST']}:3001/#{I18n.locale}/api/v1/players/#{nickname}/validate_password",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
      },
      body: { password: new_password }.to_json
    )

    json = JSON.parse(response.body)

    if response.code != 200
      errors[:new_password] = json["error"]
      render "validate_new_password", formats: :json, status: :unprocessable_entity, locals: { errors: errors }
      return
    end

    # 4. Запись нового пароля
    hash_pass = json["hash"]

    payload = {
      nickname: nickname,
      password: hash_pass
    }

    produce_with_retries("change_password", payload.to_json)
    produce_with_retries("change_password_mc", payload.to_json)

    flash[:notice] = t('change_password.password_changed')

    REDIS_CLIENT.del(session[:password_reset_key])
    session.delete(:password_reset_key)
    session.delete(:login_mode) if @login_mode

    render "validate_new_password", formats: :json, status: :ok
  end

  def load_punishment_appeal
    punishment_id = params[:id]

    response = HTTParty.get(
      "http://#{ENV['HOST']}:3001/api/v1/user/punishment_appeal/#{punishment_id}",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
      }
    )

    if response.success? && response.parsed_response["appeal"].present?
      render json: {
        appeal: {
          status: response["appeal"]["status"],
          can_repeal: response["appeal"]["can_repeal"],
          message: response["appeal"]["message"],
          admin_comment: response["appeal"]["admin_comment"]
        }
      }
    else
      render json: {
        appeal: {
          status: "",
          can_repeal: true,
          message: "",
          admin_comment: ""
        }
      }
    end
  end

  def send_punishment_appeal
    punishment_id = params[:id].to_i
    message = params[:message]

    # Базовая валидация
    if message.blank? || message.length > 500
      return render json: { success: false }
    end

    # Отправка kafka сообщения
    produce_with_retries(
      "change_punishment_appeal",
      payload: {
        id: punishment_id,
        message: message
      }
    )

    render json: { success: true }
  end

  def send_punishment_appeal_revoke
    punishment_id = params[:id].to_i

    # Отправка kafka сообщения
    produce_with_retries(
      "drop_punishment_appeal",
      payload: {
        id: punishment_id
      }
    )

    render json: { success: true }
  end

  def revoke_report
    # Проверяем наличие ID жалобы
    unless params[:id].present?
      render json: { error: I18n.t('reports.errors.missing_report_id') }, status: :unprocessable_entity
      return
    end
    
    begin
      # Отправляем запрос на auth_service для отзыва жалобы
      response = HTTParty.post(
        "http://#{ENV['HOST']}:3001/api/v1/reports/revoke/#{params[:id]}",
        headers: {
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
        }
      )
      
      # Если запрос успешен, возвращаем ответ от auth_service
      if response.code == 200
        render json: JSON.parse(response.body), status: :ok
      else
        error_message = I18n.t('reports.errors.revoke_report_error')

        render json: { error: error_message }, status: response.code
      end
    rescue RestClient::ExceptionWithResponse => e
      # Обрабатываем ошибки с ответом от сервера
      begin
        error_data = JSON.parse(e.response.body)
        render json: { error: I18n.t('reports.errors.revoke_report_error') }, status: e.response.code
      rescue
        render json: { error: I18n.t('reports.errors.revoke_report_error') }, status: :internal_server_error
      end
    rescue => e
      # Обрабатываем другие исключения
      Rails.logger.error "Error revoking report: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: I18n.t('reports.errors.revoke_report_failed') }, status: :internal_server_server_error
    end
  end

  private

  def extract_files_from_params(params)
    files = []
    if params[:files].present?
      if params[:files].is_a?(Array)
        files = params[:files]
      elsif params[:files].is_a?(ActionController::Parameters)
        files = params[:files].to_unsafe_h.values
      end
    end
    files.select { |file| file.is_a?(ActionDispatch::Http::UploadedFile) }
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
