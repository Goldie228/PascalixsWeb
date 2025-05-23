class McOnlineStatusJob < ApplicationJob
  include SuckerPunch::Job

  def perform(nickname, user_id)
    return unless user_still_on_profile?(nickname)

    punishments = fetch_punishments(user_id)

    if punishments.any? { |p| p["type"].to_s.downcase == "ban" }
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

  def fetch_punishments(user_id)
    punishments_json = REDIS_CLIENT.hget("punishments:#{user_id}", "data")
    return [] unless punishments_json.present?

    JSON.parse(punishments_json)
  rescue JSON::ParserError => e
    Rails.logger.error "Ошибка парсинга наказаний для #{user_id}: #{e.message}"
    []
  end
end
