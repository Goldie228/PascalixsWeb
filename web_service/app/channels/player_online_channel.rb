class PlayerOnlineChannel < ApplicationCable::Channel
  def subscribed
    stream_from "player_online:#{params[:nickname]}"
    REDIS_CLIENT.set("profile_active:#{params[:nickname]}", "true")
    McOnlineStatusJob.perform_later(params[:nickname])
  end

  def unsubscribed
    REDIS_CLIENT.del("profile_active:#{params[:nickname]}")
    ActionCable.server.broadcast("player_online:#{params[:nickname]}", "false")
  end
end
