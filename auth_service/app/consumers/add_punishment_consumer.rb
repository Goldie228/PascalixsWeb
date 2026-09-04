class AddPunishmentConsumer < ApplicationConsumer
  REQUIRED_KEYS = %i[user_id bad_user_id type rule_number issued_at].freeze

  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      missing = REQUIRED_KEYS - payload.keys
      next if missing.any?

      payload[:type] = payload[:type].to_s.downcase

      reason = PunishmentReason.find_by(
        punishment_type: payload[:type],
        rule_number: payload[:rule_number]
      )
      next unless reason

      punishment = UsersPunishment.create!(
        user_id: payload[:user_id],
        bad_user_id: payload[:bad_user_id],
        type: payload[:type],
        issued_at: Time.iso8601(payload[:issued_at]),
        duration: payload[:duration],
        expires_at: payload[:expires_at] ? Time.iso8601(payload[:expires_at]) : nil,
        active: payload.fetch(:active, true),
        punishment_reason: reason
      )

      Rails.logger.info "[AddPunishment] Created id=#{punishment.id} user_id=#{punishment.user_id} type=#{punishment.type} rule=#{reason.rule_number}"
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "[AddPunishment] Reason not found: type=#{payload[:type]} rule=#{payload[:rule_number]}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[AddPunishment] Validation failed: #{e.record.errors.full_messages.first}"
    rescue => e
      handle_error(e)
    end
  end
end
