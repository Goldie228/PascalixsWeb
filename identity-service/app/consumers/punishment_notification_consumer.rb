class PunishmentNotificationConsumer < ApplicationConsumer
  REQUIRED_KEYS = %i[user_id type reason].freeze

  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      unless validate_required_keys(payload, REQUIRED_KEYS)
        next
      end

      case payload[:type]&.to_s
      when 'issued'
        notify_punishment_issued(payload)
      when 'resolved', 'cancelled'
        notify_punishment_resolved(payload)
      else
        Rails.logger.warn "[PunishmentNotification] Unknown punishment type: #{payload[:type]}"
      end
    rescue => e
      handle_error(e, type: payload[:type], user_id: payload[:user_id])
    end
  end

  private

  def notify_punishment_issued(payload)
    user_id = payload[:user_id]
    user = find_user(user_id)
    return unless user

    # Send email notification
    UserMailer.with(user_id: user_id, punishment: payload).punishment_issued.deliver_later

    # Send push notification
    NotificationService.push(user_id, {
      type: 'punishment',
      title: 'New Punishment',
      message: "You received a #{payload[:type]} punishment: #{payload[:reason]}"
    })

    log_event('punishment_issued', { user_id: user_id, type: payload[:type] })
  end

  def notify_punishment_resolved(payload)
    user_id = payload[:user_id]
    user = find_user(user_id)
    return unless user

    # Send email notification
    UserMailer.with(user_id: user_id, punishment: payload).punishment_resolved.deliver_later

    # Send push notification
    NotificationService.push(user_id, {
      type: 'punishment_resolved',
      title: 'Punishment Resolved',
      message: "Your #{payload[:type]} punishment has been resolved"
    })

    log_event('punishment_resolved', { user_id: user_id, type: payload[:type] })
  end
end
