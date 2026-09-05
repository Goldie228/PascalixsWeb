class UnifiedPunishmentAppealConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      begin
        payload = parse_payload(message.payload)
        next unless payload

        punishment_id = payload.dig('payload', 'id') || payload.dig(:payload, :id)
        next unless punishment_id

        users_punishment = UsersPunishment.find_by(id: punishment_id)
        next unless users_punishment

        case message.topic
        when 'identity.punishment.appeal.created'
          handle_change_appeal(payload, users_punishment)
        when 'identity.punishment.appeal.dropped'
          handle_drop_appeal(payload, users_punishment)
        end
      rescue => e
        handle_error(e, topic: message.topic, punishment_id: punishment_id)
      end
    end
  end

  private

  def handle_change_appeal(payload, users_punishment)
    user_message = payload.dig('payload', 'message')&.to_s&.strip
    return unless user_message

    appeal = UserPunishmentAppeal.find_or_initialize_by(punishment_id: users_punishment.id)
    appeal.user_message = user_message
    appeal.status = 'pending'
    appeal.admin_comment = nil
    appeal.can_reappeal = true if appeal.can_reappeal != true

    if appeal.persisted?
      Rails.logger.info "Appeal updated: punishment_id=#{users_punishment.id}"
    else
      Rails.logger.info "Appeal created: punishment_id=#{users_punishment.id}"
    end

    appeal.save!
    Rails.logger.info "Appeal saved: ID=#{appeal.id} status=#{appeal.status}"
  end

  def handle_drop_appeal(payload, users_punishment)
    appeal = UserPunishmentAppeal.find_by(punishment_id: users_punishment.id)
    if appeal
      appeal.destroy!
      Rails.logger.info "Appeal deleted: ID=#{appeal.id}"
    else
      Rails.logger.debug "No appeal for punishment_id=#{users_punishment.id}"
    end
  end
end
