class TwoFactorAuthChannel < ApplicationCable::Channel
  def subscribed
    stream_from "two_factor_auth:#{params[:user_id]}"
    TwoFactorUpdateJob.perform_async(params[:user_id])
  end
end
