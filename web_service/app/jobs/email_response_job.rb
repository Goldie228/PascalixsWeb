class EmailResponseJob < ApplicationJob
  include SuckerPunch::Job

  def perform(user_id)
    redis = Redis.new(url: ENV.fetch("REDIS_URL"))
    response = redis.get("email_data:#{user_id}")

    if response
      data = JSON.parse(response)

      ActionCable.server.broadcast("email:#{user_id}", { time: data["time"] })
    end
  end
end
