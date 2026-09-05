class EmailResponseJob < ApplicationJob
  include SuckerPunch::Job

  def perform(user_id)
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))

    30.times do |attempt|
      response = redis.get("email_data:#{user_id}")

      if response
        data = JSON.parse(response)
        ActionCable.server.broadcast("email:#{user_id}", { time: data["time"] })
        break
      else
        sleep 1
      end
    end
  end
end
