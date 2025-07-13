class UpdatePunishmentStatusConsumer < Karafka::BaseConsumer
  BATCH_SIZE = 500

  def consume
    Rails.logger.info "[Karafka] 🔄 Запуск обновления punishment_status для всех пользователей"

    total_updated_users = 0
    total_expired_punishments = 0

    User.includes(:discord_account, :minecraft_account, :issued_punishments)
        .find_each(batch_size: BATCH_SIZE) do |user|
      begin
        expired = expire_old_punishments(user)
        total_expired_punishments += expired
        UserDataProducer.publish(user)
        total_updated_users += 1
        Rails.logger.debug "[Karafka] ✅ Обновлён пользователь #{user.id}, истекло наказаний: #{expired}"
      rescue => e
        Rails.logger.error "[Karafka] ⚠️ Ошибка при обновлении пользователя #{user.id}: #{e.message}"
      end
    end

    Rails.logger.info "[Karafka] ✅ Обновление завершено — пользователей: #{total_updated_users}, истекших наказаний: #{total_expired_punishments}"
  end

  private

  def expire_old_punishments(user)
    now = Time.current
    expired = user.issued_punishments
                  .where(active: true)
                  .where("expires_at IS NOT NULL AND expires_at <= ?", now)

    count = expired.count
    return 0 if count == 0

    expired.update_all(active: false)
    Rails.logger.info "[Karafka] 🧹 Сброшено #{count} наказаний для пользователя #{user.id} (истекли)"

    count
  end
end
