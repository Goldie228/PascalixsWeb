class McOnlineStatusJob < ApplicationJob
  include SuckerPunch::Job

  def perform(nickname)
    return unless user_still_on_profile?(nickname)

    response = REDIS_CLIENT.get("player_online:#{nickname}")

    if response.present?
      ActionCable.server.broadcast("player_online:#{nickname}", "true")
    else
      ActionCable.server.broadcast("player_online:#{nickname}", "false")
    end

    if user_still_on_profile?(nickname)
      McOnlineStatusJob.perform_in(1.minute, nickname) if user_still_on_profile?(nickname)
    end
  end

  private

  def user_still_on_profile?(nickname)
    REDIS_CLIENT.get("profile_active:#{nickname}").present?
  end
end
