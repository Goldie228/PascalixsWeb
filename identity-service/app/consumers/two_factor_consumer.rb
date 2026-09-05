class TwoFactorConsumer < ApplicationConsumer
  require "rotp"

  def consume
    begin
      messages.each do |message|
        process_message(message)
      end
    rescue => e
      Rails.logger.error "[2FA] Error: #{e.message}"
    end
  end

  private

  def process_message(message)
    begin
      raw_payload = message.payload
      payload = raw_payload.is_a?(String) ? JSON.parse(raw_payload) : raw_payload

      return unless payload

      case payload["type"]
      when "status_request"
        handle_status_request(payload)
      when "verify_code"
        handle_code_verification(payload)
      when "resend_code"
        handle_resend_request(payload)
      else
        Rails.logger.warn "[2FA] Unknown message type: #{payload["type"]}"
      end
    rescue => e
      Rails.logger.error "[2FA] Message error: #{e.message.slice(0, 100)}"
      Rails.logger.error "[2FA] Message details - Topic: #{message.topic}, " +
        "Partition: #{message.partition}, Offset: #{message.offset}"
      Rails.logger.error "[2FA] Error backtrace:\n#{e.backtrace.take(10).join("\n")}"
    end
  end

  def handle_status_request(payload)
    user_id = payload["user_id"]
    user = User.find(user_id)

    send_qr_code(user)

    if user.otp_secret.blank?
      user.otp_secret = User.generate_otp_secret
      user.save

      UserDataProducer.publish(user)
    end

    send_email_code(user, payload["locale"])
  end

  def send_qr_code(user)
    qr_code_url = user.generate_otp_qr_code
    send_redis_response(user.id, qr_code_url)
  end

  def send_redis_response(user_id, qr_code_url)
    if REDIS_CLIENT.get("2fa_auth_responses:#{user_id}").nil?
      response_data = { user_id: user_id, qr_code_url: qr_code_url }
      REDIS_CLIENT.setex("2fa_auth_responses:#{user_id}", 120, response_data.to_json)
      REDIS_CLIENT.publish("2fa_auth_responses_channel", response_data.to_json)

      Rails.logger.info "[2FA] QR code sent"
    end
  end

  def handle_code_verification(payload)
    user = User.find(payload["user_id"])
    code = payload["code"]

    valid_time = code_time_valid?(user.id)

    if valid_time
      valid_email_code = email_code_valid?(user.id, code)
      valid_totp_code = totp_code_valid?(user, code)
      valid = valid_time && (valid_email_code || valid_totp_code)
    else
      valid = false
    end

    send_code_validity_to_redis(user.id, valid)
  end

  def send_code_validity_to_redis(user_id, valid)
    message = { user_id: user_id, valid: valid }.to_json
    REDIS_CLIENT.publish("code_validity_updates", message)
    Rails.logger.info "[2FA] Sent: #{message}"
  end

  def code_time_valid?(user_id)
    raw_data = REDIS_CLIENT.get("email_data:#{user_id}")
    return false if raw_data.nil?
    true
  end

  def email_code_valid?(user_id, code)
    raw_data = REDIS_CLIENT.get("email_data:#{user_id}")
    return false if raw_data.nil?

    data = JSON.parse(raw_data)
    email_code = data["code"]
    email_code == code
  end

  def totp_code_valid?(user, code)
    totp = ROTP::TOTP.new(user.otp_secret, drift_behind: 30, drift_ahead: 30)
    user.validate_and_consume_otp!(code)
  end

  def send_email_code(user, locale)
    begin
      if can_send_email?(user.id)
        Rails.logger.info "[2FA] Email sent with code"

        Karafka.producer.produce_async(
          topic: 'notification.email.sent',
          payload: {
            user_id: user.id,
            locale: locale,
            email: user.email,
            code: user.current_otp,
            otp_valid_until: get_otp_valid_until(user.id)
          }.to_json
        )

        Rails.logger.info "[2FA] Email sent with code: #{user.current_otp}!"
      end
    rescue => e
      Rails.logger.error "[2FA] Error sending email: #{e.message.slice(0, 100)}"
    end
  end

  def get_otp_valid_until(user_id)
    (Time.current.in_time_zone(get_user_locale(user_id)) + 2.minutes).strftime("%H:%M:%S")
  end

  def can_send_email?(user_id)
    REDIS_CLIENT.get("email_data:#{user_id}").nil?
  end

  def send_response(payload)
    begin
        Karafka.producer.produce_async(
          topic: 'identity.two_factor.responses',
        payload: payload.to_json
      )
      Rails.logger.info "[2FA] Sent to two_factor_responses"
    rescue => e
      Rails.logger.error "[2FA] Error sending to two_factor_responses: #{e.message.slice(0, 100)}"
    end
  end

  def handle_resend_request(payload)
    Rails.logger.info "[2FA] Handling resend code request for user: #{payload["user_id"]}"
    user = find_user(payload["user_id"])
    return unless user

    send_email_code(user, payload["locale"])

    response = {
      correlation_id: payload["correlation_id"],
      status: "success"
    }
    send_response(response)
  end
end
