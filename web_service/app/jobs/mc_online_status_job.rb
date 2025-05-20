class McOnlineStatusJob < ApplicationJob
  include SuckerPunch::Job

  def perform(nickname)
    Rails.logger.info "[McOnlineStatusJob] Запуск для #{nickname}"

    return unless user_still_on_profile?(nickname)

    response = REDIS_CLIENT.get("player_online:#{nickname}")
    Rails.logger.debug "[McOnlineStatusJob] Получен статус из Redis: #{response}"

    if response.present?
      Rails.logger.info "[McOnlineStatusJob] Игрок #{nickname} онлайн"
      ActionCable.server.broadcast("player_online:#{nickname}", "true")
    else
      Rails.logger.info "[McOnlineStatusJob] Игрок #{nickname} оффлайн"
      ActionCable.server.broadcast("player_online:#{nickname}", "false")
    end

    if user_still_on_profile?(nickname)
      Rails.logger.debug "[McOnlineStatusJob] Игрок #{nickname} все еще на профиле, перезапускаю задачу"
      McOnlineStatusJob.perform_in(1.minute, nickname) if user_still_on_profile?(nickname)
    else
      Rails.logger.info "[McOnlineStatusJob] Игрок #{nickname} покинул профиль, прекращаю обновления"
    end
  end

  private

  def user_still_on_profile?(nickname)
    active = REDIS_CLIENT.get("profile_active:#{nickname}").present?
    Rails.logger.debug "[McOnlineStatusJob] Проверка активности профиля #{nickname}: #{active}"
    active
  end
end
