class DropPunishmentAppealConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        payload = message.payload["payload"] || message.payload
        punishment_id = payload["id"]

        Rails.logger.info "Попытка удаления обращения: ID=#{punishment_id}"

        users_punishment = UsersPunishment.find_by(id: punishment_id)
        next unless users_punishment

        appeal = UserPunishmentAppeal.find_by(punishment_id: punishment_id)
        if appeal.present?
          appeal.destroy!
          Rails.logger.info "Обращение удалено: ID=#{appeal.id}"
        else
          Rails.logger.info "Нет обращения для удаления: punishment_id=#{punishment_id}"
        end

      rescue => e
        Rails.logger.error "Ошибка при удалении обращения для punishment_id=#{payload["id"]}: #{e.message}"
        Rails.logger.debug e.backtrace.join("\n")
      end
    end
  end
end
