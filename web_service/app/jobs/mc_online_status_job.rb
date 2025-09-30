class McOnlineStatusJob < ApplicationJob
  include SuckerPunch::Job

  def perform(nickname, user_id)
    return unless user_still_on_profile?(nickname)

    punishments = fetch_punishments(nickname)

    if is_banned?(punishments)
      ActionCable.server.broadcast("player_online:#{nickname}", "ban")
    else
      response = REDIS_CLIENT.get("player_online:#{nickname}")
      online_status = response.present? ? "true" : "false"
      ActionCable.server.broadcast("player_online:#{nickname}", online_status)
    end

    McOnlineStatusJob.set(wait: 1.minute).perform_later(nickname, user_id) if user_still_on_profile?(nickname)
  end

  private

  def user_still_on_profile?(nickname)
    REDIS_CLIENT.get("profile_active:#{nickname}").present?
  end

  def is_banned?(punishments)
    punishments.any? do |p|
      p[:type].to_s.downcase == "ban" && punishment_active?(p)
    end
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
end
