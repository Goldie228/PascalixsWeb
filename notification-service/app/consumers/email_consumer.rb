class EmailConsumer < ApplicationConsumer
  def consume
    Rails.logger.info "EmailConsumer work!"

    messages.each do |message|
      begin
        payload = message.payload
        Rails.logger.info "Message: #{payload}"

        user_id = payload["user_id"]
        email = payload["email"]
        code = payload["code"]
        otp_valid_until = payload["otp_valid_until"]

        I18n.locale = payload["locale"]

        UserMailer.two_factor_code(email, code, otp_valid_until).deliver_now

        send_email_code(user_id, otp_valid_until, code)

        Rails.logger.info "Message sended!"
      rescue => e
        Rails.logger.error "Error: #{e.message}"
      end
    end
  end

  def send_email_code(user_id, time, code)
    data = {
      time: time,
      code: code
    }.to_json

    REDIS_CLIENT.setex("email_data:#{user_id}", 120, data)
    REDIS_CLIENT.publish("email_data_updates", { user_id: user_id, time: time, code: code }.to_json)

    Rails.logger.info "Redis message is sent and published!"
  end
end
