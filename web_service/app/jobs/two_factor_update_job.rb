class TwoFactorUpdateJob < ApplicationJob
  include SuckerPunch::Job

  def perform(user_id)
    response = REDIS_CLIENT.get("2fa_auth_responses:#{user_id}")

    if response
      data = JSON.parse(response)
      ActionCable.server.broadcast(
        "two_factor_auth:#{user_id}",
        { qr_code_url: data["qr_code_url"].gsub(/<\?xml.*?\?>/, "").strip }
      )
    end
  end
end
