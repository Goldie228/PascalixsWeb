class AddPunishmentConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        raw_payload = message.payload
        parsed_json = raw_payload.is_a?(String) ? JSON.parse(raw_payload, symbolize_names: true) : raw_payload.deep_symbolize_keys

        Rails.logger.debug "📨 Получено сообщение на создание наказания: #{parsed_json.inspect}"

        required_keys = [ :user_id, :bad_user_id, :type, :reason, :issued_at ]
        missing = required_keys.select { |k| !parsed_json.key?(k) }

        if missing.any?
          Rails.logger.warn "⚠️ Пропущены обязательные поля: #{missing.join(', ')}"
          next
        end

        punishment = UsersPunishment.create!(
          user_id: parsed_json[:user_id],
          bad_user_id: parsed_json[:bad_user_id],
          type: parsed_json[:type],
          reason: parsed_json[:reason],
          issued_at: Time.parse(parsed_json[:issued_at]),
          duration: parsed_json[:duration],
          expires_at: parsed_json[:expires_at] ? Time.parse(parsed_json[:expires_at]) : nil,
          active: parsed_json.fetch(:active, true)
        )

        Rails.logger.info "✅ Наказание успешно создано: #{punishment.id} для bad_user_id=#{punishment.bad_user_id}"

      rescue JSON::ParserError => e
        Rails.logger.error "🛑 Ошибка парсинга JSON: #{e.message}\n#{e.backtrace.join("\n")}"
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "🛑 Ошибка валидации наказания: #{e.message}\n#{e.record.errors.full_messages.join(', ')}"
      rescue => e
        Rails.logger.error "🛑 Необработанная ошибка: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end
