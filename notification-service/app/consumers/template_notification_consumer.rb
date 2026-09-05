class TemplateNotificationConsumer < ApplicationConsumer
  # Processes template-based notification events from the 'notification.template' topic.
  # Supports email, SMS, and push notification types via templating.
  #
  # Expected message payload:
  #   {
  #     "template": "welcome",
  #     "recipient": "user@example.com",
  #     "variables": {
  #       "username": "John",
  #       "verify_url": "https://..."
  #     }
  #   }

  def process_message(message)
    data = JSON.parse(message.payload)
    send_template_notification(data)
  end

  private

  def send_template_notification(data)
    template_name = data['template']
    recipient = data['recipient']
    variables = data['variables'] || {}

    template_data = fetch_template(template_name)
    return log_and_skip(recipient, 'template not found') unless template_data

    rendered = render_template(template_data['content'], variables)

    case template_data['type']
    when 'email'
      send_email_notification(recipient, template_data['subject'], rendered)
    when 'sms'
      send_sms_notification(recipient, rendered)
    when 'push'
      send_push_notification(recipient, template_data['title'], rendered)
    else
      Rails.logger.warn "Unknown notification type in template: #{template_data['type']}"
    end

    Rails.logger.info "Template notification sent: #{template_name} to #{recipient}"
  rescue => e
    Rails.logger.error "Failed to send template notification: #{e.message}"
    raise
  end

  # Fetch a notification template from identity service with Redis caching
  #
  # @param template_name [String] template identifier
  # @return [Hash, nil] template data with keys: type, subject, content, title
  def fetch_template(template_name)
    cache_key = "template:#{template_name}"
    cached = REDIS_CLIENT.get(cache_key)

    if cached
      return JSON.parse(cached)
    end

    identity_url = ENV.fetch('IDENTITY_SERVICE_URL', nil)
    api_key = ENV.fetch('INTER_SERVICE_API_KEY', nil)

    return nil unless identity_url && api_key

    url = "#{identity_url}/api/v1/templates/#{template_name}"
    response = HTTParty.get(
      url,
      headers: { 'Authorization' => "Bearer #{api_key}" }
    )

    return nil unless response.success?

    template_data = JSON.parse(response.body)
    REDIS_CLIENT.setex(cache_key, 3_600, template_data.to_json)
    template_data
  rescue => e
    Rails.logger.warn "Failed to fetch template #{template_name}: #{e.message}"
    nil
  end

  # Simple ERB-based template rendering with variable substitution
  #
  # @param content [String] template content with {{variable}} placeholders
  # @param variables [Hash] variable values
  # @return [String] rendered content
  def render_template(content, variables)
    variables.each do |key, value|
      content = content.gsub("{{#{key}}}", value.to_s)
    end
    content
  end

  def send_email_notification(recipient, subject, body)
    MailerService.send_email(
      to: recipient,
      subject: subject,
      body: body
    )
  end

  def send_sms_notification(recipient, body)
    # TODO: Implement SMS sending (e.g. via Twilio)
    Rails.logger.info "SMS notification queued for #{recipient}: #{body}"
  end

  def send_push_notification(recipient, title, body)
    FCMService.send(
      token: recipient,
      title: title,
      body: body
    )
  end

  def log_and_skip(recipient, reason)
    Rails.logger.warn "Skipping template notification to #{recipient}: #{reason}"
  end
end
