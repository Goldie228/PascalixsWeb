class PlayerOnlineChannel < ApplicationCable::Channel
  def subscribed
    stream_from "player_online:#{params[:nickname]}"
    REDIS_CLIENT.set("profile_active:#{params[:nickname]}", "true")

    # Предполагаем, что у вас есть доступ к current_user или params[:user_id]
    user_id = params[:user_id] || ""

    McOnlineStatusJob.perform_later(params[:nickname], user_id)
  end

  def unsubscribed
    REDIS_CLIENT.del("profile_active:#{params[:nickname]}")
    ActionCable.server.broadcast("player_online:#{params[:nickname]}", "false")
  end
end
