class ChangePunishmentAppealConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        payload = message.payload["payload"] || message.payload

        punishment_id = payload["id"]
        user_message  = payload["message"].to_s.strip

        Rails.logger.info "Обработка обращения на наказание ID=#{punishment_id} | Сообщение: #{user_message}"

        users_punishment = UsersPunishment.find_by(id: punishment_id)
        next unless users_punishment

        appeal = UserPunishmentAppeal.find_or_initialize_by(punishment_id: punishment_id)

        appeal.user_message  = user_message
        appeal.status        = "pending"
        appeal.admin_comment = nil
        appeal.can_reappeal  = true if appeal.can_reappeal != true

        if appeal.persisted?
          Rails.logger.info "Обращение уже существует — обновляем"
        else
          Rails.logger.info "Создаём новое обращение"
        end

        appeal.save!

        Rails.logger.info "Обращение сохранено: ID=#{appeal.id} | Status=#{appeal.status}"

      rescue => e
        Rails.logger.error "❌ Ошибка при обработке обращения punishment_id=#{payload["id"]}: #{e.message}"
        Rails.logger.debug e.backtrace.join("\n")
      end
    end
  end
end
