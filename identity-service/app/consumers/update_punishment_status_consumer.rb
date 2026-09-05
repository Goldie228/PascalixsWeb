class UpdatePunishmentStatusConsumer < ApplicationConsumer
  BATCH_SIZE = 500

  def consume
    Rails.logger.info "[UpdatePunishmentStatus] Starting punishment status update"

    total_updated_users = 0
    total_expired = 0

    User.includes(:discord_account, :minecraft_account, :issued_punishments)
        .find_each(batch_size: BATCH_SIZE) do |user|
      begin
        expired = expire_old_punishments(user)
        total_expired += expired
        UserDataProducer.publish(user)
        total_updated_users += 1
      rescue => e
        Rails.logger.error "[UpdatePunishmentStatus] Error for user #{user.id}: #{e.message}"
      end
    end

    Rails.logger.info "[UpdatePunishmentStatus] Done — users: #{total_updated_users}, expired: #{total_expired}"
  end

  private

  def expire_old_punishments(user)
    now = Time.current
    expired = user.issued_punishments.where(active: true).where('expires_at IS NOT NULL AND expires_at <= ?', now)
    count = expired.count
    return 0 if count.zero?

    expired.update_all(active: false)
    count
  end
end
