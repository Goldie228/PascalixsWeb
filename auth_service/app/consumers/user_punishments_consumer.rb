class UserPunishmentsConsumer < Karafka::BaseConsumer
  TTL_SECONDS = 15.minutes.to_i

  def consume
    Rails.logger.info("UserPunishmentsConsumer стартовал. Получено сообщений: #{messages.size}")

    messages.each do |message|
      Rails.logger.debug("Обработка сообщения с payload: #{message.payload}")

      data = message.payload rescue nil
      unless data.is_a?(Hash)
        Rails.logger.error("Не удалось распарсить: #{message.payload}")
        next
      end

      user_id = data["user_id"]
      if user_id.blank?
        Rails.logger.warn("Получено сообщение без user_id. Данные: #{data.inspect}")
        next
      end

      Rails.logger.info("Обработка наказаний для пользователя с ID: #{user_id}")

      punishments = UsersPunishment.where(active: true, bad_user_id: user_id)

      # ⏳ Убираем истекшие
      now = Time.current
      valid_punishments = punishments.select do |p|
        p.expires_at.nil? || p.expires_at > now
      end

      if valid_punishments.empty?
        Rails.logger.info("Нет активных наказаний для пользователя #{user_id}")
        next
      else
        Rails.logger.info("Найдено #{valid_punishments.size} актуальных наказаний для пользователя #{user_id}")
      end

      punishments_data = valid_punishments.as_json(only: [:id, :user_id, :type, :reason, :issued_at, :expires_at])
      Rails.logger.debug("Данные наказаний: #{punishments_data.inspect}")

      REDIS_CLIENT.hset("punishments:#{user_id}", "data", punishments_data.to_json)
      REDIS_CLIENT.expire("punishments:#{user_id}", TTL_SECONDS)

      Rails.logger.info("Сохранены наказания в Redis для #{user_id}, TTL=#{TTL_SECONDS} сек")
    end
  end
end
