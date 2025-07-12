class AdminController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :add_punishment ]
  before_action :is_admin?, :update_users_data

  def players
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
      render json: { error: "Никнейм не передан" }, status: :bad_request and return
    end

    # 🔍 Профиль
    profile_key  = "public_profile:#{nickname}"
    profile_json = REDIS_CLIENT.get(profile_key)

    unless profile_json.present?
      Rails.logger.info "⏳ Нет данных в Redis. Запрос к API: public_profile"
      response = HTTParty.get("http://#{ENV['HOST']}:3001/api/v1/players/#{nickname}")

      if response.success?
        profile_json = response.body
        Rails.logger.debug "🔁 Получен профиль из API: #{profile_json}"
      else
        Rails.logger.error "❌ Ошибка получения профиля из API: статус #{response.code}"
      end
    end

    unless profile_json.present?
      Rails.logger.error "❌ Профиль не найден ни в Redis, ни через API"
      render json: { error: "Профиль не найден" }, status: :not_found and return
    end

    begin
      profile = JSON.parse(profile_json, symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.error "❌ Ошибка парсинга JSON профиля: #{e.message}"
      render json: { error: "Невозможно обработать данные профиля" }, status: :unprocessable_entity and return
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

    Rails.logger.debug "🧩 Профиль разобран: email=#{email}, minecraft=#{minecraft_nick.inspect}, discord=#{discord_username}##{discord_discriminator}, pass_access=#{pass_access}, user_id=#{user_id}"

    # 🔍 Наказания
    punishments_key   = "punishment_history:#{minecraft_nick}"
    punishments_json  = REDIS_CLIENT.get(punishments_key)

    unless punishments_json.present?
      Rails.logger.info "📡 Нет данных о наказаниях в Redis. Запрос к API: punishment_history"
      response = HTTParty.get("http://#{ENV['HOST']}:3001/api/v1/players/#{nickname}/punishments")

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
        reason: p[:reason],
        issued_at: issued.in_time_zone(time_zone).strftime("%d.%m.%Y %H:%M:%S"),
        expires_at: expires ? expires.in_time_zone(time_zone).strftime("%d.%m.%Y %H:%M:%S") : "—",
        status: is_active ? "Активен" : "Истёк",
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
      punishments: punishments
    }, status: :ok
  end

  def add_punishment
    nickname = params[:nickname]
    Rails.logger.debug "📥 Получен запрос add_punishment для nickname: #{nickname.inspect}"

    # 🔍 Профиль
    profile_key  = "public_profile:#{nickname}"
    profile_json = REDIS_CLIENT.get(profile_key)

    unless profile_json.present?
      Rails.logger.info "⏳ Нет данных в Redis для #{profile_key}. Запрос к API: public_profile"
      response = HTTParty.get("http://#{ENV['HOST']}:3001/api/v1/players/#{nickname}")

      if response.success?
        profile_json = response.body
        Rails.logger.debug "🔁 Профиль получен из API: #{profile_json}"
      else
        Rails.logger.error "❌ Ошибка получения профиля из API: HTTP #{response.code}"
      end
    end

    unless profile_json.present?
      Rails.logger.error "❌ Профиль не найден ни в Redis, ни через API"
      return render json: { error: "Профиль игрока не найден" }, status: :not_found
    end

    begin
      profile = JSON.parse(profile_json, symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.error "❌ Ошибка парсинга JSON профиля: #{e.message}"
      return render json: { error: "Невозможно обработать данные профиля" }, status: :unprocessable_entity
    end

    user_id = profile[:user_id]
    issuer  = current_user
    Rails.logger.debug "👤 Создаётся наказание: issuer_id=#{issuer.id}, bad_user_id=#{user_id}"

    # Вычисление времени
    duration  = params[:duration].to_i
    unit      = params[:unit]
    issued_at = Time.current

    expires_at = case unit
                 when "minutes" then issued_at + duration.minutes
                 when "hours"   then issued_at + duration.hours
                 when "days"    then issued_at + duration.days
                 else nil
                 end

    payload = {
      user_id: user_id,
      bad_user_id: issuer.id,
      type: params[:type],
      reason: params[:reason],
      issued_at: issued_at,
      duration: duration,
      expires_at: expires_at,
      active: true
    }

    Rails.logger.debug "📦 Kafka payload: #{payload.inspect}"

    begin
      produce_with_retries("add_punishment", payload.to_json)
      Rails.logger.info "✅ Payload отправлен в Kafka: add_punishment"
    rescue => e
      Rails.logger.error "❌ Ошибка при отправке в Kafka: #{e.message}"
      return render json: { error: "Ошибка отправки в очередь задач" }, status: :internal_server_error
    end

    render json: { status: "ok", message: "Ограничение добавлено и ожидает обработки" }, status: :created
  end

  def cancel_punishment
    nickname   = params[:nickname].to_s.strip
    issued_at = Time.strptime(params[:issued_at], "%d.%m.%Y %H:%M").utc

    if nickname.blank? || issued_at.nil?
      return render json: { error: "Неверные параметры" }, status: :unprocessable_entity
    end

    payload = {
      nickname: nickname,
      issued_at: issued_at
    }

    Rails.logger.debug "📦 Kafka payload: #{payload.inspect}"

    begin
      produce_with_retries("cancel_punishment", payload.to_json)
      Rails.logger.info "✅ Payload отправлен в Kafka: cancel_punishment"
    rescue => e
      Rails.logger.error "❌ Ошибка при отправке в Kafka: #{e.message}"
      return render json: { error: "Ошибка отправки в очередь задач" }, status: :internal_server_error
    end

    render json: { status: "ok", message: "Наказание отменено" }
  end

  def change_password
    nickname         = params[:nickname].to_s.strip
    new_password     = params[:new_password].to_s
    confirm_password = params[:confirm_password].to_s

    Rails.logger.debug "📥 Получен запрос смены пароля: nickname=#{nickname}"

    if new_password.blank? || confirm_password.blank?
      Rails.logger.warn "⚠️ new_password или confirm_password не заполнены"
      render json: { error: "Пароль и подтверждение обязательны" }, status: :unprocessable_entity and return
    end

    if new_password != confirm_password
      Rails.logger.warn "⚠️ Пароли не совпадают: new='#{new_password}' confirm='#{confirm_password}'"
      render json: { error: "Пароли не совпадают" }, status: :unprocessable_entity and return
    end

    Rails.logger.debug "🛰 Отправка запроса к /validate_password: nickname=#{nickname}"

    response = HTTParty.post(
      "http://#{ENV['HOST']}:3001/api/v1/players/#{nickname}/validate_password",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      },
      body: { password: new_password }.to_json
    )

    Rails.logger.debug "📡 Ответ от /validate_password: код=#{response.code}"

    if response.code != 200
      render json: { error: "Пароль не прошёл валидацию" }, status: :unprocessable_entity and return
    else
      content_type = response.headers["content-type"]

      if content_type.include?("application/json")
        begin
          json = JSON.parse(response.body)
          hash_pass = json["hash"]

          if hash_pass.blank?
            Rails.logger.error "❌ /validate_password вернул пустой hash для nickname=#{nickname}"
            render json: { error: "Пароль не прошёл валидацию" }, status: :unprocessable_entity and return
          end

          Rails.logger.debug "🔁 Получен хеш пароля: #{hash_pass}"
        rescue JSON::ParserError => e
          Rails.logger.error "❌ Ошибка парсинга JSON: #{e.message}\n#{e.backtrace.join("\n")}"
          render json: { error: "Неверный формат JSON от хеш-сервиса" }, status: :internal_server_error and return
        end
      else
        Rails.logger.error "⚠️ /validate_password вернул ответ не в формате JSON: #{response.body.inspect}"
        render json: { error: "Сервис хеширования вернул неподдерживаемый формат" }, status: :unprocessable_entity and return
      end
    end

    begin
      payload = {
        nickname: nickname,
        password: hash_pass
      }

      Rails.logger.debug "📤 Отправка хеша в топики: #{payload.inspect}"
      produce_with_retries("change_password", payload.to_json)
      produce_with_retries("change_password_mc", payload.to_json)
      Rails.logger.info "Пароль отправлен в Kafka успешно"

      render json: { status: "ok", message: "Пароль успешно обновлён" }, status: :ok
    rescue => e
      Rails.logger.error "Ошибка отправки в Kafka: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: "Ошибка при обновлении пароля" }, status: :internal_server_error
    end
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
