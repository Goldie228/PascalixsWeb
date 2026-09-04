class UserPunishmentsConsumer < ApplicationConsumer
  TTL_SECONDS = 15.minutes.to_i

  def consume
    messages.each do |message|
      data = parse_payload(message.payload)
      next unless data.is_a?(Hash)

      user_id = data['user_id']
      next unless user_id.present?

      now = Time.current
      punishments = UsersPunishment
        .where(active: true, bad_user_id: user_id)
        .where('expires_at IS NULL OR expires_at > ?', now)

      if punishments.empty?
        REDIS_CLIENT.del("punishments:#{user_id}")
        next
      end

      punishments_data = punishments.as_json(only: [:id, :user_id, :type, :reason, :issued_at, :expires_at])
      REDIS_CLIENT.hset("punishments:#{user_id}", "data", punishments_data.to_json)
      REDIS_CLIENT.expire("punishments:#{user_id}", TTL_SECONDS)
      Rails.logger.info "Punishments cached for user_id=#{user_id}, TTL=#{TTL_SECONDS}s"
    rescue => e
      handle_error(e, user_id: user_id)
    end
  end
end
