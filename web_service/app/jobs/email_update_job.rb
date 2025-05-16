class EmailUpdateJob < ApplicationJob
  include SuckerPunch::Job

  def perform(user_id)
    response = REDIS_CLIENT.get("email_data:#{user_id}")

    if response
      data = JSON.parse(response)
      ActionCable.server.broadcast(
        "email:#{user_id}",
        { time: data["time"] }
      )
    end
  end
end
