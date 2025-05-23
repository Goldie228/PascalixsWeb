class UserPunishmentsConsumer < Karafka::BaseConsumer
  def consume
    Rails.logger.info("UserPunishmentsConsumer стартовал. Получено сообщений: #{messages.size}")

    messages.each do |message|
      Rails.logger.debug("Обработка сообщения с payload: #{message.payload}")

      begin
        data = message.payload
        Rails.logger.debug("Распарсенные данные: #{data.inspect}")
      rescue => e
        Rails.logger.error("Не удалось распарсить: #{data}")
        next
      end

      user_id = data["user_id"]
      if user_id.blank?
        Rails.logger.warn("Получено сообщение без user_id. Данные: #{data.inspect}")
        next
      end

      Rails.logger.info("Обработка наказаний для пользователя с ID: #{user_id}")

      punishments = UsersPunishment.where(active: true, bad_user_id: user_id)
      if punishments.empty?
        Rails.logger.info("Нет активных наказаний для пользователя #{user_id}")
        next
      else
        Rails.logger.info("Найдено #{punishments.size} активных наказаний для пользователя #{user_id}")
      end

      punishments_data = punishments.as_json(only: [ :id, :user_id, :type, :reason, :issued_at, :expires_at ])
      Rails.logger.debug("Данные наказаний для пользователя #{user_id}: #{punishments_data.inspect}")

      REDIS_CLIENT.hset("punishments:#{user_id}", "data", punishments_data.to_json)
      REDIS_CLIENT.expire("punishments:#{user_id}", 86400)
      Rails.logger.info("Сохранены наказания для пользователя #{user_id} в Redis с TTL 86400 секунд")
    end
  end
end
