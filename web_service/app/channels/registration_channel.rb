class RegistrationChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "user_id: #{params[:user_id]}"
    stream_from "registration_channel_#{params[:user_id]}"
  end
end
