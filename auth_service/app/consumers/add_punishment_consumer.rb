class AddPunishmentConsumer < Karafka::BaseConsumer
  REQUIRED_KEYS = %i[user_id bad_user_id type rule_number issued_at].freeze

  def consume
    messages.each do |message|
      payload = parse(message.payload)

      missing = REQUIRED_KEYS - payload.keys
      if missing.any?
        Rails.logger.warn "⚠️ Missing keys: #{missing.join(', ')}"
        next
      end

      payload[:type] = payload[:type].to_s.downcase

      begin
        reason = PunishmentReason.find_by!(
          punishment_type: payload[:type],
          rule_number:     payload[:rule_number]
        )

        punishment = UsersPunishment.create!(
          user_id:            payload[:user_id],
          bad_user_id:        payload[:bad_user_id],
          type:               payload[:type],
          issued_at:          Time.iso8601(payload[:issued_at]),
          duration:           payload[:duration],
          expires_at:         payload[:expires_at] ? Time.iso8601(payload[:expires_at]) : nil,
          active:             payload.fetch(:active, true),
          punishment_reason:  reason
        )

        Rails.logger.info "✅ Punishment created id=#{punishment.id} user_id=#{punishment.user_id} type=#{punishment.type} rule=#{reason.rule_number}"
      rescue ActiveRecord::RecordNotFound
        Rails.logger.error "🛑 Reason not found: type=#{payload[:type]} rule=#{payload[:rule_number]}"
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "🛑 Validation failed: #{e.record.errors.full_messages.first}"
      rescue JSON::ParserError
        Rails.logger.error "🛑 JSON parse error"
      rescue => e
        Rails.logger.error "🛑 Unexpected error: #{e.message}"
      end
    end
  end

  private

  def parse(raw)
    raw.is_a?(String) ? JSON.parse(raw, symbolize_names: true) : raw.deep_symbolize_keys
  end
end
