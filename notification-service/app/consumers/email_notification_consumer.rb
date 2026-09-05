class EmailNotificationConsumer < ApplicationConsumer
  # Processes email notification events from the 'notification.email' topic.
  # Supported event types: welcome, password_reset, email_change,
  #                        punishment_issued, punishment_resolved
  #
  # Expected message payload:
  #   {
  #     "type": "welcome",
  #     "user_id": 123,
  #     "new_email": "new@example.com",  # for email_change only
  #     "punishment_type": "ban",         # for punishment_* only
  #     "reason": "...",                  # for punishment_* only
  #     "issuer": "mod_user",             # for punishment_* only
  #     "expires_at": "2025-01-01T00:00:00Z" # for punishment_* only
  #   }

  def process_message(message)
    data = JSON.parse(message.payload)
    type = data['type']

    case type
    when 'welcome'
      send_welcome_email(data)
    when 'password_reset'
      send_password_reset_email(data)
    when 'email_change'
      send_email_change_email(data)
    when 'punishment_issued'
      send_punishment_issued_email(data)
    when 'punishment_resolved'
      send_punishment_resolved_email(data)
    else
      Rails.logger.warn "Unknown email notification type: #{type}"
    end
  end

  private

  def send_welcome_email(data)
    user = fetch_user(data['user_id'])
    return log_and_skip(data, 'user not found') unless user

    token = generate_token
    REDIS_CLIENT.setex("email_token:#{token}", 3_600, user['email'].to_s)

    verify_url = "#{frontend_url}/verify?token=#{token}"

    MailerService.send_email(
      to: user['email'],
      subject: 'Welcome to Pascalixs!',
      template: 'welcome',
      variables: {
        username: user['discord_username'] || user['nickname'],
        verify_url: verify_url
      }
    )

    Rails.logger.info "Welcome email sent to #{user['email']} (user_id: #{user['id']})"
  rescue => e
    Rails.logger.error "Failed to send welcome email: #{e.message}"
    raise
  end

  def send_password_reset_email(data)
    user = fetch_user(data['user_id'])
    return log_and_skip(data, 'user not found') unless user

    token = generate_token
    REDIS_CLIENT.setex(
      "reset_token:#{token}",
      3_600,
      { user_id: user['id'], email: user['email'] }.to_json
    )

    reset_url = "#{frontend_url}/reset-password?token=#{token}"

    MailerService.send_email(
      to: user['email'],
      subject: 'Password Reset - Pascalixs',
      template: 'password_reset',
      variables: {
        username: user['discord_username'] || user['nickname'],
        reset_url: reset_url
      }
    )

    Rails.logger.info "Password reset email sent to #{user['email']} (user_id: #{user['id']})"
  rescue => e
    Rails.logger.error "Failed to send password reset email: #{e.message}"
    raise
  end

  def send_email_change_email(data)
    user = fetch_user(data['user_id'])
    return log_and_skip(data, 'user not found') unless user

    token = generate_token
    REDIS_CLIENT.setex(
      "email_change_token:#{token}",
      3_600,
      { user_id: user['id'], new_email: data['new_email'] }.to_json
    )

    confirm_url = "#{frontend_url}/confirm-email?token=#{token}"

    MailerService.send_email(
      to: data['new_email'],
      subject: 'Email Change Confirmation - Pascalixs',
      template: 'email_change',
      variables: {
        username: user['discord_username'] || user['nickname'],
        confirm_url: confirm_url
      }
    )

    Rails.logger.info "Email change email sent to #{data['new_email']} (user_id: #{user['id']})"
  rescue => e
    Rails.logger.error "Failed to send email change email: #{e.message}"
    raise
  end

  def send_punishment_issued_email(data)
    user = fetch_user(data['user_id'])
    return log_and_skip(data, 'user not found') unless user

    MailerService.send_email(
      to: user['email'],
      subject: "Punishment Issued - Pascalixs",
      template: 'punishment_issued',
      variables: {
        username: user['discord_username'] || user['nickname'],
        punishment_type: data['punishment_type'],
        reason: data['reason'],
        issuer: data['issuer'],
        expires_at: data['expires_at']
      }
    )

    Rails.logger.info "Punishment issued email sent to #{user['email']} (user_id: #{user['id']})"
  rescue => e
    Rails.logger.error "Failed to send punishment issued email: #{e.message}"
    raise
  end

  def send_punishment_resolved_email(data)
    user = fetch_user(data['user_id'])
    return log_and_skip(data, 'user not found') unless user

    MailerService.send_email(
      to: user['email'],
      subject: "Punishment Resolved - Pascalixs",
      template: 'punishment_resolved',
      variables: {
        username: user['discord_username'] || user['nickname'],
        punishment_type: data['punishment_type'],
        issuer: data['issuer']
      }
    )

    Rails.logger.info "Punishment resolved email sent to #{user['email']} (user_id: #{user['id']})"
  rescue => e
    Rails.logger.error "Failed to send punishment resolved email: #{e.message}"
    raise
  end

  # Fetch user data from identity service
  #
  # @param user_id [Integer, String]
  # @return [Hash, nil] user data hash or nil
  def fetch_user(user_id)
    identity_url = ENV.fetch('IDENTITY_SERVICE_URL', nil)
    api_key = ENV.fetch('INTER_SERVICE_API_KEY', nil)

    return nil unless identity_url && api_key

    url = "#{identity_url}/api/v1/users/#{user_id}"
    response = HTTParty.get(
      url,
      headers: { 'Authorization' => "Bearer #{api_key}" }
    )

    return nil unless response.success?

    JSON.parse(response.body)
  rescue => e
    Rails.logger.warn "Failed to fetch user #{user_id}: #{e.message}"
    nil
  end

  def generate_token
    SecureRandom.urlsafe_base64(32)
  end

  def frontend_url
    ENV.fetch('WEB_PORTAL_URL', 'https://pascalixs.com')
  end

  def log_and_skip(_data, reason)
    Rails.logger.warn "Skipping email notification: #{reason}"
  end
end
