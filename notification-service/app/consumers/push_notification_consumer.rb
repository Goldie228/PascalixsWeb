class PushNotificationConsumer < ApplicationConsumer
  # Processes push notification events from the 'notification.push' topic.
  #
  # Expected message payload:
  #   {
  #     "user_id": 123,
  #     "type": "punishment",
  #     "title": "Punishment Issued",
  #     "message": "You have been banned for 24 hours"
  #   }

  def process_message(message)
    data = JSON.parse(message.payload)
    send_push_notification(data)
  end

  private

  def send_push_notification(data)
    user_id = data['user_id']
    type = data['type']
    message = data['message']
    title = data['title'] || 'Notification'

    # Fetch user's FCM token from Redis
    fcm_token = REDIS_CLIENT.get("fcm_token:#{user_id}")
    return log_and_skip(user_id, 'no FCM token') unless fcm_token

    FCMService.send(
      token: fcm_token,
      title: title,
      body: message,
      data: {
        type: type,
        user_id: user_id.to_s
      }
    )

    # Store notification in database
    Notification.create!(
      user_id: user_id,
      type: type,
      title: title,
      message: message,
      read: false
    )

    Rails.logger.info "Push notification sent to user #{user_id} (type: #{type})"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Push notification failed - record not found for user #{data['user_id']}: #{e.message}"
    raise
  rescue => e
    Rails.logger.error "Failed to send push notification: #{e.message}"
    raise
  end

  def log_and_skip(user_id, reason)
    Rails.logger.warn "Skipping push notification for user #{user_id}: #{reason}"
  end
end
