class EmailChannel < ApplicationCable::Channel
  def subscribed
    stream_from "email:#{params[:user_id]}"
    EmailUpdateJob.perform_async(params[:user_id])
  end
end
