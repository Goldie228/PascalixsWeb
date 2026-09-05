class NotificationService
  class << self
    # Отправка push-уведомления пользователю
    def push(user_id, data)
      payload = {
        user_id: user_id,
        notification: {
          type: data[:type],
          title: data[:title],
          message: data[:message],
          timestamp: Time.current.iso8601
        }
      }.to_json

      ApplicationProducer.call(
        topic: 'notification.push',
        payload: payload
      )
    rescue => e
      Rails.logger.error "[NotificationService] Failed to push notification for user #{user_id}: #{e.message}"
    end

    # Отправка email-уведомления (через mailer)
    def email(mailer_method, user_id, opts = {})
      user = User.find_by(id: user_id)
      return unless user

      mailer = UserMailer.with(user_id: user_id, **opts).public_send(mailer_method)
      mailer.deliver_later
    rescue => e
      Rails.logger.error "[NotificationService] Failed to send email #{mailer_method} for user #{user_id}: #{e.message}"
    end
  end
end
