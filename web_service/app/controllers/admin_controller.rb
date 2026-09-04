
class AdminController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :add_punishment ]
  before_action :is_admin?

  def players
    update_users_data

    filters   = Array(params[:filters])
    per_page  = (params[:per_page] || 25).to_i.clamp(1, 100)
    page      = (params[:page] || 1).to_i.clamp(1, 10_000)
    order     = %w[asc desc].include?(params[:order]) ? params[:order] : "asc"
    sort      = %w[minecraft_nickname discord_username punishment_status is_added].include?(params[:sort]) ? params[:sort] : "minecraft_nickname"
    search    = params[:search].to_s.strip.downcase
    offset    = (page - 1) * per_page

    filter_map = {
      "pass"   => { column: "is_added", values: [ 1 ] },
      "nopass" => { column: "is_added", values: [ 0 ] },
      "ban"    => { column: "punishment_status", values: [ 3 ] },
      "mute"   => { column: "punishment_status", values: [ 2 ] }
    }

    filter_groups = Hash.new { |h, k| h[k] = [] }
    filters.each do |f|
      map = filter_map[f]
      filter_groups[map[:column]] += map[:values] if map
    end

    filter_clauses = filter_groups.map do |column, values|
      "#{column} IN (#{values.uniq.join(',')})"
    end
    filter_where = filter_clauses.any? ? "(#{filter_clauses.join(" AND ")})" : nil


    search_where = if search.present?
      term = "'%#{search.gsub("'", "''")}%'"
      <<~SQL.squish
        (lower(minecraft_nickname) LIKE #{term} OR lower(discord_username) LIKE #{term})
      SQL
    end

    where_clauses = [ filter_where, search_where ].compact
    where_sql     = where_clauses.any? ? "WHERE #{where_clauses.join(" AND ")}" : ""

    @total_count = ClickHouse.connection.select_value("SELECT count() FROM users #{where_sql}").to_i
    @total_pages = (@total_count / per_page.to_f).ceil.clamp(1, 10_000)
    page = page > @total_pages ? 1 : page

    @page     = page
    @per_page = per_page
    offset    = (page - 1) * per_page

    sql = <<~SQL
      SELECT user_id, discord_username, minecraft_nickname, is_added, punishment_status
      FROM users
      #{where_sql}
      ORDER BY #{sort} #{order}
      LIMIT #{per_page} OFFSET #{offset}
    SQL

    @players = ClickHouse.connection.select_all(sql)
  end

  def edit_player
    nickname = params[:nickname].to_s.strip

    Rails.logger.debug "➡️ Запрошен edit_player для nickname: #{nickname.inspect}"

    if nickname.blank?
      Rails.logger.warn "⚠️ Никнейм не передан"
      render json: { error: I18n.t('admin.players.errors.nickname_required') }, status: :bad_request and return
    end

    # 🔍 Профиль
    profile_key  = "public_profile:#{nickname}"
    profile_json = REDIS_CLIENT.get(profile_key)

    unless profile_json.present?
      Rails.logger.info "⏳ Нет данных в Redis. Запрос к API: public_profile"
      response = HTTParty.get(
        "#{ENV['AUTH_SERVICE_URL']}/api/v1/players/#{nickname}",
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
        }
      )
      if response.success?
        profile_json = response.body
        Rails.logger.debug "🔁 Получен профиль из API: #{profile_json}"
      else
        Rails.logger.error "❌ Ошибка получения профиля из API: статус #{response.code}"
      end
    end

    unless profile_json.present?
      Rails.logger.error "❌ Профиль не найден ни в Redis, ни через API"
      render json: { error: I18n.t('admin.players.errors.profile_not_found') }, status: :not_found and return
    end

    begin
      profile = JSON.parse(profile_json, symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.error "❌ Ошибка парсинга JSON профиля: #{e.message}"
      render json: { error: I18n.t('admin.players.errors.profile_parse_error') }, status: :unprocessable_entity and return
    end

    # 🎯 Извлечение вложенных данных
    minecraft_data = profile.dig(:minecraft_account, :table) || {}
    discord_data   = profile.dig(:discord_account, :table) || {}

    minecraft_nick        = minecraft_data[:nickname]
    discord_username      = discord_data[:username]
    discord_discriminator = discord_data[:discriminator]
    email                 = profile[:email] || "—"
    pass_access           = profile[:is_added] == true
    user_id               = profile[:user_id]
    is_sponsor            = profile[:is_sponsor]

    Rails.logger.debug "🧩 Профиль разобран: email=#{email}, minecraft=#{minecraft_nick.inspect}, discord=#{discord_username}##{discord_discriminator}, pass_access=#{pass_access}, user_id=#{user_id}"

    # 🔍 Наказания
    punishments_key   = "punishment_history:#{minecraft_nick}"
    punishments_json  = REDIS_CLIENT.get(punishments_key)

    unless punishments_json.present?
      Rails.logger.info "📡 Нет данных о наказаниях в Redis. Запрос к API: punishment_history"
      response = HTTParty.get(
        "#{ENV['AUTH_SERVICE_URL']}/api/v1/players/#{nickname}/punishments",
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
        }
      )
      if response.success?
        Rails.logger.debug "🧾 Raw JSON из API punishment_history: #{response.body}"
        begin
          test_parse = JSON.parse(response.body)
          Rails.logger.debug "✅ JSON punishment_history разобран: #{test_parse.class} с #{test_parse.size} элементами"
          punishments_json = response.body
        rescue JSON::ParserError => e
          Rails.logger.error "❌ Ошибка парсинга JSON punishments: #{e.message}"
        end
      else
        Rails.logger.error "❌ API не вернул успех на запрос punishments"
      end
    end

    # Финальная сборка наказаний
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
        reason: p[:reason] || '—',
        issued_at: issued.in_time_zone(time_zone).strftime("%d.%m.%Y %H:%M:%S"),
        expires_at: expires ? expires.in_time_zone(time_zone).strftime("%d.%m.%Y %H:%M:%S") : "—",
        status: is_active ? I18n.t('admin.players.punishments.status.active') : I18n.t('admin.players.punishments.status.expired'),
        issued_at_raw: issued
      }
    end

    punishments = punishments.sort_by { |p| -p[:issued_at_raw].to_i }
    punishments.each { |p| p.delete(:issued_at_raw) }

    Rails.logger.debug "📄 Наказания (#{punishments.size}): #{punishments.inspect}"

    display_name = minecraft_nick.presence || "#{discord_username}#{discord_discriminator ? "##{discord_discriminator}" : ""}"

    render json: {
      email: email,
      discord: "@#{discord_username}#{discord_discriminator ? "##{discord_discriminator}" : ""}",
      pass_access: pass_access,
      nickname: display_name,
      is_sponsor: is_sponsor,
      punishments: punishments
    }, status: :ok
  end

  def add_punishment
    nickname = params[:nickname]
    Rails.logger.debug "📥 Получен запрос add_punishment для nickname: #{nickname.inspect}"

    profile_key  = "public_profile:#{nickname}"
    profile_json = REDIS_CLIENT.get(profile_key)

    unless profile_json.present?
      Rails.logger.info "⏳ Нет данных в Redis для #{profile_key}. Запрос к API: public_profile"
      response = HTTParty.get(
        "#{ENV['AUTH_SERVICE_URL']}/api/v1/players/#{nickname}",
        headers: { "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}" }
      )

      if response.success?
        profile_json = response.body
      else
        Rails.logger.error "❌ Ошибка получения профиля: HTTP #{response.code}"
      end
    end

    unless profile_json.present?
      return render json: { error: I18n.t('admin.players.errors.profile_not_found') }, status: :not_found
    end

    begin
      profile = JSON.parse(profile_json, symbolize_names: true)
    rescue JSON::ParserError => e
      return render json: { error: I18n.t('admin.players.errors.profile_parse_error') }, status: :unprocessable_entity
    end

    user_id    = profile[:user_id]
    issuer     = current_user
    type       = params[:type].to_s
    rule_number = params[:rule_number].to_i
    duration   = params[:duration].to_i
    unit       = params[:unit]

    unless %w[ban mute].include?(type)
      return render json: { error: I18n.t('admin.players.errors.invalid_type') }, status: :unprocessable_entity
    end

    if rule_number <= 0
      return render json: { error: I18n.t('admin.players.errors.invalid_rule_number') }, status: :unprocessable_entity
    end

    issued_at  = Time.current
    expires_at = case unit
                 when "minutes" then issued_at + duration.minutes
                 when "hours"   then issued_at + duration.hours
                 when "days"    then issued_at + duration.days
                 else nil
                 end

    payload = {
      user_id: user_id,
      bad_user_id: issuer.id,
      type: type,
      rule_number: rule_number,
      issued_at: issued_at.iso8601,
      duration: duration.positive? ? duration : nil,
      expires_at: expires_at&.iso8601,
      active: true
    }

    Rails.logger.debug "📦 Отправляем минимальный payload в Kafka: #{payload.inspect}"

    begin
      produce_with_retries('identity.punishment.added', payload.to_json)
      Rails.logger.info "✅ Успешно отправлено в Karafka"
      render json: { status: "ok", message: I18n.t('admin.players.notifications.restriction_added') }, status: :created
    rescue => e
      Rails.logger.error "❌ Ошибка Kafka: #{e.message}"
      render json: { error: I18n.t('common.errors.kafka_send_error') }, status: :internal_server_error
    end
  end

  def cancel_punishment
    nickname   = params[:nickname].to_s.strip
    issued_at = Time.strptime(params[:issued_at], "%d.%m.%Y %H:%M").utc

    if nickname.blank? || issued_at.nil?
      return render json: { error: I18n.t('common.errors.invalid_params') }, status: :unprocessable_entity
    end

    payload = {
      nickname: nickname,
      issued_at: issued_at
    }

    Rails.logger.debug "📦 Kafka payload: #{payload.inspect}"

    begin
      produce_with_retries('identity.punishment.cancelled', payload.to_json)
      Rails.logger.info "✅ Payload отправлен в Kafka: cancel_punishment"
    rescue => e
      Rails.logger.error "❌ Ошибка при отправке в Kafka: #{e.message}"
      return render json: { error: I18n.t('common.errors.kafka_send_error') }, status: :internal_server_error
    end

    render json: { status: "ok", message: I18n.t('admin.players.notifications.restriction_canceled') }
  end

  def change_password
    nickname         = params[:nickname].to_s.strip
    new_password     = params[:new_password].to_s
    confirm_password = params[:confirm_password].to_s

    Rails.logger.debug "📥 Получен запрос смены пароля: nickname=#{nickname}"

    if new_password.blank? || confirm_password.blank?
      Rails.logger.warn "⚠️ new_password или confirm_password не заполнены"
      render json: { error: I18n.t('admin.players.security.password_required') }, status: :unprocessable_entity and return
    end

    if new_password != confirm_password
      Rails.logger.warn "⚠️ Пароли не совпадают: new='#{new_password}' confirm='#{confirm_password}'"
      render json: { error: I18n.t('admin.players.security.password_mismatch') }, status: :unprocessable_entity and return
    end

    Rails.logger.debug "🛰 Отправка запроса к /validate_password: nickname=#{nickname}"

    response = HTTParty.post(
      "#{ENV['AUTH_SERVICE_URL']}/api/v1/players/#{nickname}/validate_password",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
      },
      body: { password: new_password }.to_json
    )

    Rails.logger.debug "📡 Ответ от /validate_password: код=#{response.code}"

    if response.code != 200
      render json: { error: I18n.t('admin.players.security.password_validation_failed') }, status: :unprocessable_entity and return
    else
      content_type = response.headers["content-type"]

      if content_type.include?("application/json")
        begin
          json = JSON.parse(response.body)
          hash_pass = json["hash"]

          if hash_pass.blank?
            Rails.logger.error "❌ /validate_password вернул пустой hash для nickname=#{nickname}"
            render json: { error: I18n.t('admin.players.security.password_hash_error') }, status: :unprocessable_entity and return
          end

          Rails.logger.debug "🔁 Получен хеш пароля: #{hash_pass}"
        rescue JSON::ParserError => e
          Rails.logger.error "❌ Ошибка парсинга JSON: #{e.message}\n#{e.backtrace.join("\n")}"
          render json: { error: I18n.t('common.errors.json_parse_error') }, status: :internal_server_error and return
        end
      else
        Rails.logger.error "⚠️ /validate_password вернул ответ не в формате JSON: #{response.body.inspect}"
        render json: { error: I18n.t('common.errors.invalid_response_format') }, status: :unprocessable_entity and return
      end
    end

    begin
      payload = {
        nickname: nickname,
        password: hash_pass
      }

      Rails.logger.debug "📤 Отправка хеша в топики: #{payload.inspect}"
      produce_with_retries('identity.user.password_changed', payload.to_json)
      produce_with_retries('game.player.password_changed', payload.to_json)
      Rails.logger.info "Пароль отправлен в Kafka успешно"

      render json: { status: "ok", message: I18n.t('admin.players.security.password_changed') }, status: :ok
    rescue => e
      Rails.logger.error "Ошибка отправки в Kafka: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: I18n.t('common.errors.password_update_error') }, status: :internal_server_error
    end
  end

  def update_account
    nickname = params[:nickname].to_s.strip
    email    = params[:email].to_s.strip
    discord  = params[:discord].to_s.strip
    pass     = ActiveModel::Type::Boolean.new.cast(params[:pass])
    sponsor  = ActiveModel::Type::Boolean.new.cast(params[:sponsor])

    Rails.logger.debug "📥 Обновление аккаунта: nickname=#{nickname} email=#{email} discord=#{discord} pass=#{pass} sponsor=#{sponsor}"

    # Получение данных пользователя для сравнения
    if nickname.blank?
      Rails.logger.warn "⚠️ Никнейм не передан"
      render json: { error: I18n.t('admin.players.errors.nickname_required') }, status: :bad_request and return
    end

    # 🔍 Профиль
    profile_key  = "public_profile:#{nickname}"
    profile_json = REDIS_CLIENT.get(profile_key)

    unless profile_json.present?
      Rails.logger.info "⏳ Нет данных в Redis. Запрос к API: public_profile"
      response = HTTParty.get(
        "#{ENV['AUTH_SERVICE_URL']}/api/v1/players/#{nickname}",
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
        }
      )

      if response.success?
        profile_json = response.body
        Rails.logger.debug "🔁 Получен профиль из API: #{profile_json}"
      else
        Rails.logger.error "❌ Ошибка получения профиля из API: статус #{response.code}"
      end
    end

    unless profile_json.present?
      Rails.logger.error "❌ Профиль не найден ни в Redis, ни через API"
      render json: { error: I18n.t('admin.players.errors.profile_not_found') }, status: :not_found and return
    end

    begin
      profile = JSON.parse(profile_json, symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.error "❌ Ошибка парсинга JSON профиля: #{e.message}"
      render json: { error: I18n.t('admin.players.errors.profile_parse_error') }, status: :unprocessable_entity and return
    end

    minecraft_data = profile.dig(:minecraft_account, :table) || {}
    discord_data   = profile.dig(:discord_account, :table) || {}

    discord_username      = discord_data[:username]
    discord_discriminator = discord_data[:discriminator]
    email_profile         = profile[:email] || "—"
    pass_access           = profile[:is_added] == true
    sponsor_access        = profile[:is_sponsor] == true
    user_id               = profile[:user_id]

    Rails.logger.debug "🧩 Профиль разобран: email=#{email}, discord=#{discord_username}##{discord_discriminator}, pass_access=#{pass_access}, sponsor_access=#{sponsor_access}, user_id=#{user_id}"

    # Разбор Discord ввода
    discord_input       = discord.delete_prefix("@").strip
    input_parts         = discord_input.split("#")
    input_username      = input_parts[0]
    input_discriminator = input_parts[1] if input_parts.size > 1

    # Сравнение
    email_changed    = email.present? && email != email_profile
    pass_changed     = pass != pass_access
    sponsor_changed  = !sponsor.nil? && sponsor != sponsor_access
    discord_changed  = (
      discord_username.present? &&
      (
        input_username != discord_username ||
        (discord_discriminator.present? && input_discriminator != discord_discriminator)
      )
    )

    # Итоговые значения
    changed_email    = email_changed   ? email : nil
    changed_discord  = discord_changed ? "@#{input_username}#{input_discriminator ? "##{input_discriminator}" : ""}" : nil
    changed_pass     = pass_changed    ? pass : nil
    changed_sponsor  = sponsor_changed ? sponsor : nil

    Rails.logger.debug "✏️ Изменения от админа: email=#{changed_email.inspect}, discord=#{changed_discord.inspect}, pass=#{changed_pass.inspect}, sponsor=#{changed_sponsor.inspect}"

    if changed_pass.nil? && changed_discord.nil? && changed_email.nil? && changed_sponsor.nil?
      render json: { error: 'No changes' }, status: :bad_request and return
    end

    if user_id.nil?
      render json: { error: I18n.t('admin.players.errors.user_data_error') }, status: :bad_request and return
    end

    # Смена pass (как у тебя)
    if !changed_pass.nil?
      password = nil

      if changed_pass
        response = HTTParty.get(
          "#{ENV['AUTH_SERVICE_URL']}/api/v1/users/#{user_id}/get_password",
          headers: {
            "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
          }
        )
        if response.success?
          response_data = response.body
          Rails.logger.debug "🔁 Получен пароль из API: #{response_data}"
        else
          Rails.logger.error "❌ Ошибка получения профиля из API: статус #{response.code}"
        end

        unless response_data.present?
          render json: { error: I18n.t('admin.players.errors.password_not_found') }, status: :not_found and return
        end

        begin
          password = JSON.parse(response_data, symbolize_names: true)[:hash]
        rescue JSON::ParserError => e
          Rails.logger.error "❌ Ошибка парсинга JSON: #{e.message}"
          render json: { error: I18n.t('common.errors.json_parse_error') }, status: :unprocessable_entity and return
        end
      end

      payload = { nickname: nickname, pass: changed_pass, password: password }
      produce_with_retries('game.player.status_changed', payload.to_json)
    end

    if !changed_email.nil? || !changed_discord.nil? || !changed_pass.nil? || !changed_sponsor.nil?
      payload = {
        user_id: user_id,
        email:   changed_email,
        discord: changed_discord,
        sponsor: changed_sponsor,
        pass:    changed_pass
      }
      produce_with_retries('identity.user.profile_updated', payload.to_json)
    end

    REDIS_CLIENT.del("public_profile:#{nickname}")
    Rails.logger.debug "🧹 Кеш профиля удалён: public_profile:#{nickname}"

    render json: { status: "ok", message: I18n.t('admin.players.notifications.profile_updated') }, status: :ok
  end

  def delete_account
    nickname = params[:nickname]

    # Отнимаем проходку
    payload = {
      nickname: nickname,
      pass: false,
      password: nil
    }
      produce_with_retries('game.player.status_changed', payload.to_json)

    # Удаляем игрока с вэба
    payload = {
      nickname: nickname
    }
      produce_with_retries('identity.user.deleted', payload.to_json)

    render json: { success: true, message: I18n.t("admin.players.notifications.account_deleted") }
  end

  def removed_players
    search_param  = params[:search].to_s.strip.downcase
    allowed_sorts = %w[nickname deleted_at]
    sort_key      = allowed_sorts.include?(params[:sort]) ? params[:sort] : 'deleted_at'
    order_dir     = %w[asc desc].include?(params[:order]) ? params[:order] : 'desc'
    per_page      = (params[:per_page] || 25).to_i.clamp(1, 100)
    page          = (params[:page] || 1).to_i.clamp(1, 10_000)

    @rem_players = []
    @total_pages = 0
    @total_count = 0
    @page = page
    @per_page = per_page

    begin
      api_url  = "#{ENV['AUTH_SERVICE_URL']}/api/v1/removed_players"
      response = HTTParty.get(
        api_url,
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
        }
      )

      if response.code != 200
        flash.now[:alert] = t('removed_players.errors.failed_to_load')
        return
      end

      raw_list = response.parsed_response
      unless raw_list.is_a?(Array)
        flash.now[:alert] = t('removed_players.errors.invalid_data')
        return
      end

      @rem_players = raw_list.map do |u|
        {
          "nickname"   => u["nickname"],
          "deleted_at" => u["deleted_at"]
        }
      end

      # Фильтрация по поиску
      if search_param.present?
        @rem_players.select! { |u| u["nickname"].to_s.downcase.include?(search_param) }
      end

      # Сортировка
      @rem_players.sort_by! do |u|
        sort_key == "deleted_at" ? (DateTime.parse(u["deleted_at"]) rescue DateTime.new) : u["nickname"].to_s.downcase
      end
      @rem_players.reverse! if order_dir == "desc"

      # Пагинация
      @total_count = @rem_players.size
      @total_pages = (@total_count / per_page.to_f).ceil.clamp(1, 10_000)
      page = page > @total_pages ? 1 : page
      @page = page
      @per_page = per_page
      offset = (page - 1) * per_page

      # Форматирование дат только для текущей страницы
      time_zone = session[:time_zone] || "UTC"
      @rem_players = @rem_players[offset, per_page] || []
      @rem_players.each do |u|
        begin
          dt = DateTime.parse(u["deleted_at"])
          local_time = dt.in_time_zone(time_zone)
          u["deleted_at"] = I18n.l(local_time, format: :long)
        rescue
          # Оставляем оригинальное значение при ошибке парсинга
        end
      end

    rescue => e
      Rails.logger.error "❌ Ошибка получения удалённых игроков: #{e.message}"
      flash.now[:alert] = t('removed_players.errors.request_error')
    end
  end

  def restore_player
    nickname = params[:nickname].to_s.strip
    return redirect_to admin_removed_players_path, alert: t('removed_players.errors.nickname_blank') if nickname.blank?

    payload = { nickname: nickname }

    begin
      produce_with_retries('identity.user.restored', payload.to_json)
      sleep 1
      redirect_to admin_removed_players_path, notice: t('removed_players.notices.restore_success')
    rescue => e
      Rails.logger.error "[RestoreUser] Ошибка отправки: #{e.message}"
      redirect_to admin_removed_players_path, alert: t('removed_players.errors.restore_failed')
    end
  end

  def add_to_removed_players
    nickname = params[:nickname].to_s.strip

    if nickname.blank?
      render json: { error: t('removed_players.errors.nickname_blank') }, status: :bad_request
      return
    end

    api_url = "#{ENV['AUTH_SERVICE_URL']}/api/v1/removed_players/add/#{nickname}"
    response = HTTParty.post(
      api_url,
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
      },
    )

    parsed = JSON.parse(response.body, symbolize_names: true)
    Rails.logger.debug parsed

    if parsed[:status]
      render json: { status: "ok", message: t('removed_players.notices.add_success') }
      return
    end

    case parsed[:error]
    when "nickname_invalid"
      render json: { error: t('removed_players.errors.nickname_invalid') }, status: :unprocessable_entity
    when"already_exists"
      render json: { error: t('removed_players.errors.already_exists') }, status: :unprocessable_entity
    else
      render json: { error: t('removed_players.errors.unknown_error') }, status: :unprocessable_entity
    end
  end

  def punishment_appeals
    # Параметры по умолчанию
    search_param  = params[:search].to_s.strip.downcase
    allowed_sorts = %w[nickname type status can_reappeal]
    sort_key      = allowed_sorts.include?(params[:sort]) ? params[:sort] : 'nickname'
    order_dir     = %w[asc desc].include?(params[:order]) ? params[:order] : 'desc'
    per_page      = (params[:per_page] || 25).to_i.clamp(1, 100)
    page          = (params[:page] || 1).to_i.clamp(1, 10_000)

    @appeals = []

    begin
      # Формируем правильный URL API с параметрами
      api_url = "#{ENV['AUTH_SERVICE_URL']}/api/v1/user/punishment_appeal_all"

      # Добавляем параметры запроса
      query_params = {
        search: params[:search],
        sort: sort_key,
        order: order_dir,
        page: page,
        per_page: per_page
      }.compact

      # Выполняем запрос к API
      response = HTTParty.get(
        api_url,
        query: query_params,
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
          "Content-Type" => "application/json"
        },
        timeout: 10
      )

      # Проверяем ответ сервера
      if response.code != 200
        flash.now[:alert] = "Ошибка при загрузке апелляций: сервер вернул код #{response.code}"
        return
      end

      # Парсим ответ
      parsed_response = response.parsed_response

      # Проверяем структуру данных
      unless parsed_response.is_a?(Hash) && parsed_response["appeals"].is_a?(Array)
        flash.now[:alert] = "Некорректный формат данных от сервера"
        return
      end

      # Получаем данные из ответа
      raw_appeals = parsed_response["appeals"]
      total_count = parsed_response["total_count"].to_i

      # Форматируем данные для вывода
      @appeals = raw_appeals.map do |appeal|
        {
          "id" => appeal["id"],
          "nickname" => appeal["nickname"],
          "type" => appeal["type"],
          "status" => appeal["status"],
          "can_reappeal" => appeal["can_reappeal"] == true
        }
      end

      # Дополнительная фильтрация по поиску (если API не поддерживает поиск)
      if search_param.present?
        @appeals.select! do |appeal|
          appeal["nickname"].to_s.downcase.include?(search_param) ||
          appeal["type"].to_s.downcase.include?(search_param) ||
          appeal["status"].to_s.downcase.include?(search_param)
        end
        total_count = @appeals.size
      end

      # Дополнительная сортировка (если API не поддерживает сортировку)
      @appeals.sort_by! do |appeal|
        case sort_key
        when "nickname"
          appeal["nickname"].to_s.downcase
        when "type"
          appeal["type"].to_s.downcase
        when "status"
          appeal["status"].to_s.downcase
        when "can_reappeal"
          appeal["can_reappeal"] ? 1 : 0
        else
          appeal["nickname"].to_s.downcase
        end
      end
      @appeals.reverse! if order_dir == 'desc'

      # Пагинация
      @total_count = total_count
      @per_page    = per_page.presence&.to_i || 20
      @page        = page.presence&.to_i || 1

      @total_pages = (@total_count / @per_page.to_f).ceil.clamp(1, 10_000)
      @page        = @page > @total_pages ? 1 : @page

      # Применяем оффсет и обрезаем записи
      offset = (@page - 1) * @per_page
      @appeals = @appeals[offset, @per_page] || []

    rescue => e
      Rails.logger.error "❌ Ошибка получения апелляций: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash.now[:alert] = "Произошла ошибка при загрузке данных: #{e.message}"
      redirect_to localized_root_path
    end
  end

  def get_punishment_appeal
    id = params[:id]
    time_zone = session[:time_zone] || "UTC"

    api_url = "#{ENV['AUTH_SERVICE_URL']}/api/v1/user/punishment_appeal/full/#{id}"
    response = HTTParty.get(
      api_url,
      headers: {
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}"
      }
    )

    appeal_data = response.parsed_response

    appeal_date_raw = appeal_data["appeal_date"]
    appeal_date_formatted = begin
      Time.parse(appeal_date_raw).in_time_zone(time_zone).strftime("%d.%m.%Y")
    rescue
      nil
    end

    render json: {
      player_name:       appeal_data["player_name"],
      punishment_type:   appeal_data["punishment_type"],
      punishment_reason: appeal_data["punishment_reason"],
      appeal_date:       appeal_date_formatted,
      appeal_message:    appeal_data["appeal_message"]
    }
  end

  def punishment_appeal_accept
    id = params[:id]
    api_url = "#{ENV['AUTH_SERVICE_URL']}/api/v1/user/punishment_appeal/delete/#{id}"

    begin
      response = HTTParty.delete(
        api_url,
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        }
      )

      render json: { success: response.code == 200 }
    rescue => e
      Rails.logger.error("Failed to delete appeal: #{e.message}")
      render json: { success: false, error: 'Ошибка соединения с API' }, status: :bad_gateway
    end
  end

  def get_punishment_appeal_data
    id = params[:id]

    api_url = "#{ENV['AUTH_SERVICE_URL']}/api/v1/user/punishment_appeal/get_admin_answer/#{id}"

    begin
      response = HTTParty.get(
        api_url,
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        }
      )

      if response.code == 200
        data = JSON.parse(response.body)

        render json: {
          admin_comment: data["admin_comment"] || "",
          can_reappeal: data["can_reappeal"]
        }
      else
        render json: { success: false, error: 'Ошибка при запросе к API' }, status: :bad_request
      end
    rescue => e
      Rails.logger.error("Failed to get appeal data: #{e.message}")
      render json: { success: false, error: 'Ошибка соединения с API' }, status: :bad_gateway
    end
  end

  def punishment_appeal_reject
    begin
      data = JSON.parse(request.body.read)

      punishment_id = data["punishment_id"].to_i
      admin_comment = data["admin_comment"] || ""
      can_reappeal = data["can_reappeal"]

      api_url = "#{ENV['AUTH_SERVICE_URL']}/api/v1/user/punishment_appeal/reject"

      response = HTTParty.post(
        api_url,
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        },
        body: {
          punishment_id: punishment_id,
          admin_comment: admin_comment,
          can_reappeal: can_reappeal
        }.to_json
      )

      if response.code == 200
        render json: { success: true }
      else
        render json: { success: false, error: 'Ошибка при запросе к API' }, status: :bad_request
      end
    rescue => e
      Rails.logger.error("Ошибка при отклонении апелляции для punishment_id=#{punishment_id}: #{e.message}")
      render json: { success: false, error: "Ошибка соединения с API" }, status: :bad_gateway
    end
  end

  def complaints
    # Параметры по умолчанию
    search_param  = params[:search].to_s.strip.downcase
    allowed_sorts = %w[sender recipient title status]
    sort_key      = allowed_sorts.include?(params[:sort]) ? params[:sort] : 'sender'
    order_dir     = %w[asc desc].include?(params[:order]) ? params[:order] : 'desc'
    per_page      = (params[:per_page] || 25).to_i.clamp(1, 100)
    page          = (params[:page] || 1).to_i.clamp(1, 10_000)

    @complaints = []
    begin
      # Формируем правильный URL API с параметрами
      api_url = "#{ENV['AUTH_SERVICE_URL']}/api/v1/admin/complaints"
      # Добавляем параметры запроса
      query_params = {
        search: params[:search],
        sort: sort_key,
        order: order_dir,
        page: page,
        per_page: per_page
      }.compact
      # Выполняем запрос к API
      response = HTTParty.get(
        api_url,
        query: query_params,
        headers: {
          "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
          "Content-Type" => "application/json"
        }
      )
      # Проверяем ответ сервера
      if response.code != 200
        flash.now[:alert] = I18n.t('admin.complaints_management.errors.server_error', code: response.code)
        return
      end
      # Парсим ответ
      parsed_response = response.parsed_response
      # Проверяем структуру данных
      unless parsed_response.is_a?(Hash) && parsed_response["complaints"].is_a?(Array)
        flash.now[:alert] = I18n.t('admin.complaints_management.errors.invalid_format')
        return
      end
      # Получаем данные из ответа
      raw_complaints = parsed_response["complaints"]
      total_count = parsed_response["total_count"].to_i
      # Форматируем данные для вывода
      @complaints = raw_complaints.map do |complaint|
        {
          "id" => complaint["id"],
          "sender" => complaint["sender"],
          "recipient" => complaint["recipient"],
          "title" => complaint["title"],
          "status" => complaint["status"],
          "reported_user_id" => complaint["reported_user_id"]  # Добавляем ID пользователя
        }
      end
    rescue => e
      Rails.logger.error "Ошибка получения жалоб: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:alert] = I18n.t('admin.complaints_management.errors.loading_error', message: e.message)
      redirect_to admin_players_path
      return
    end
    # Дополнительная фильтрация по поиску
    if search_param.present?
      @complaints.select! do |complaint|
        complaint["sender"].to_s.downcase.include?(search_param) ||
        complaint["recipient"].to_s.downcase.include?(search_param) ||
        complaint["title"].to_s.downcase.include?(search_param) ||
        complaint["status"].to_s.downcase.include?(search_param)
      end
      total_count = @complaints.size
    else
      total_count = @complaints.size
    end

    # Дополнительная сортировка
    @complaints.sort_by! do |complaint|
      case sort_key
      when "sender"
        complaint["sender"].to_s.downcase
      when "recipient"
        complaint["recipient"].to_s.downcase
      when "title"
        complaint["title"].to_s.downcase
      when "status"
        complaint["status"].to_s.downcase
      else
        complaint["sender"].to_s.downcase
      end
    end
    @complaints.reverse! if order_dir == 'desc'

    # Пагинация
    @total_count = total_count
    @per_page    = per_page.presence&.to_i || 20
    @page        = page.presence&.to_i || 1
    @total_pages = (@total_count / @per_page.to_f).ceil.clamp(1, 10_000)
    @page        = @page > @total_pages ? 1 : @page

    # Применяем оффсет и обрезаем записи
    offset = (@page - 1) * @per_page
    @complaints = @complaints[offset, @per_page] || []
  end

  def purchases
  end

  def punishment_reasons
  end

  def products
  end

  def gallery
  end

  private

  def is_admin?
    unless current_user && (current_user.role_name == "DEV" || current_user.role_name == "OWNER")
      redirect_to localized_root_path
    end
  end

  def update_users_data
    @result = ClickHouse.connection.select_all("SELECT count() AS cnt FROM users")
    count  = @result.first["cnt"].to_i
    Rails.logger.info "[Admin] Начальное количество записей в ClickHouse: #{count}"
    ready = 0

    if count.zero?
      produce_with_retries('portal.user.data_updated', payload: {})

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
      # Запускаем механизм обновления статуса наказаний
      produce_with_retries('identity.punishment.status_updated', {})
    end
  end
end
