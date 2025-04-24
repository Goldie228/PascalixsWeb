class NotificationEventsProducer < ApplicationProducer
  def self.notification_sent(notification_id, user_id, notification_type)
    call(
      topic: :notification_events,
      payload: {
        event_type: 'notification_sent',
        notification_id: notification_id,
        user_id: user_id,
        notification_type: notification_type,
        timestamp: Time.current
      }
    )
  end

  def self.notification_delivered(notification_id, user_id)
    call(
      topic: :notification_events,
      payload: {
        event_type: 'notification_delivered',
        notification_id: notification_id,
        user_id: user_id,
        timestamp: Time.current
      }
    )
  end

  def self.notification_read(notification_id, user_id)
    call(
      topic: :notification_events,
      payload: {
        event_type: 'notification_read',
        notification_id: notification_id,
        user_id: user_id,
        timestamp: Time.current
      }
    )
  end

  def self.notification_failed(notification_id, user_id, error_message)
    call(
      topic: :notification_events,
      payload: {
        event_type: 'notification_failed',
        notification_id: notification_id,
        user_id: user_id,
        error_message: error_message,
        timestamp: Time.current
      }
    )
  end
end 