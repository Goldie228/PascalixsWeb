class CancelPunishmentConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      required_keys = %i[nickname issued_at]
      next unless validate_required_keys(payload, required_keys)

      nickname = payload[:nickname].strip
      issued_at = Time.zone.parse(payload[:issued_at])
      next unless issued_at

      account = MinecraftAccount.find_by(nickname: nickname)
      next unless account

      punishment = UsersPunishment
        .where(user_id: account.user_id)
        .where('issued_at BETWEEN ? AND ?', issued_at.beginning_of_minute, issued_at.end_of_minute)
        .first

      next unless punishment

      punishment.update!(active: false)
      Rails.logger.info "[CancelPunishment] Cancelled punishment id=#{punishment.id} for user_id=#{account.user_id}"
    rescue => e
      handle_error(e, nickname: payload[:nickname])
    end
  end
end
