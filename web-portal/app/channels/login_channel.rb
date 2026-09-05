class LoginChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "LoginChannel: Подписка для correlation_id: #{params[:correlation_id]}"
    stream_from "login_channel_#{params[:correlation_id]}"
  end
end
