class CancelPunishmentConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        raw_payload = message.payload
        parsed_json = raw_payload.is_a?(String) ? JSON.parse(raw_payload, symbolize_names: true) : raw_payload.deep_symbolize_keys

        Rails.logger.debug "📨 Получено сообщение на отмену наказания: #{parsed_json.inspect}"

        required_keys = [ :nickname, :issued_at ]
        missing = required_keys.reject { |k| parsed_json.key?(k) }

        if missing.any?
          Rails.logger.warn "⚠️ Пропущены обязательные поля: #{missing.join(', ')}"
          next
        end

        nickname  = parsed_json[:nickname].strip
        issued_at = Time.zone.parse(parsed_json[:issued_at]) rescue nil

        if issued_at.nil?
          Rails.logger.error "❌ Невозможно распарсить issued_at: #{parsed_json[:issued_at].inspect}"
          next
        end

        account = MinecraftAccount.find_by(nickname: nickname)
        if account.nil?
          Rails.logger.warn "⚠️ Пользователь с ником #{nickname} не найден"
          next
        end

        user_id = account.user_id

        punishment = UsersPunishment.where(user_id: user_id)
                            .where("issued_at BETWEEN ? AND ?", issued_at.beginning_of_minute, issued_at.end_of_minute)
                            .first

        if punishment.nil?
          Rails.logger.warn "🔎 Наказание не найдено для user_id=#{user_id} с issued_at=#{issued_at}"
          next
        end

        punishment.update!(active: false)

        Rails.logger.info "✅ Наказание отменено: ID=#{punishment.id} для user_id=#{user_id}"

      rescue JSON::ParserError => e
        Rails.logger.error "🛑 Ошибка парсинга JSON: #{e.message}\n#{e.backtrace.join("\n")}"
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "🛑 Ошибка обновления наказания: #{e.message}\n#{e.record.errors.full_messages.join(', ')}"
      rescue => e
        Rails.logger.error "🛑 Необработанная ошибка: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end
