class EmailNotificationConsumer < ApplicationConsumer
  REQUIRED_KEYS = %i[type user_id].freeze

  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      unless validate_required_keys(payload, REQUIRED_KEYS)
        next
      end

      email_type = payload[:type]&.to_s

      case email_type
      when 'registration'
        send_registration_email(payload)
      when 'password_reset'
        send_password_reset_email(payload)
      when 'email_change'
        send_email_change_email(payload)
      else
        Rails.logger.warn "[EmailNotification] Unknown email type: #{email_type}"
      end
    rescue => e
      handle_error(e, type: payload[:type], user_id: payload[:user_id])
    end
  end

  private

  def send_registration_email(payload)
    user_id = payload[:user_id]
    user = find_user(user_id)
    return unless user

    UserMailer.with(user_id: user_id).welcome.deliver_later
    Rails.logger.info "[EmailNotification] Welcome email queued for user_id=#{user_id}"
  end

  def send_password_reset_email(payload)
    user_id = payload[:user_id]
    token = payload[:token]

    return if token.blank?

    UserMailer.with(user_id: user_id, token: token).password_reset.deliver_later
    Rails.logger.info "[EmailNotification] Password reset email queued for user_id=#{user_id}"
  end

  def send_email_change_email(payload)
    user_id = payload[:user_id]
    new_email = payload[:new_email]

    return if new_email.blank?

    UserMailer.with(user_id: user_id, new_email: new_email).email_changed.deliver_later
    Rails.logger.info "[EmailNotification] Email change email queued for user_id=#{user_id}"
  end
end
