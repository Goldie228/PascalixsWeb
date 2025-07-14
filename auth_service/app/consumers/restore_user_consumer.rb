class RestoreUserConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        raw_payload = message.payload
        parsed_json = raw_payload.is_a?(String) ? JSON.parse(raw_payload, symbolize_names: true) : raw_payload.deep_symbolize_keys

        required_keys = [:nickname]
        missing = required_keys.reject { |k| parsed_json.key?(k) }

        if missing.any?
          Rails.logger.warn "[RestoreUserConsumer] Пропущены обязательные поля: #{missing.join(', ')}"
          next
        end

        nickname = parsed_json[:nickname].strip
        next if nickname.blank?

        if DropedUser.exists?(name: nickname)
          DropedUser.where(name: nickname).delete_all
          Rails.logger.info "[RestoreUserConsumer] Игрок #{nickname} восстановлен (удалён из droped_users)"
        else
          Rails.logger.warn "[RestoreUserConsumer] Игрок #{nickname} не найден среди удалённых"
        end

      rescue JSON::ParserError => e
        Rails.logger.error "[RestoreUserConsumer] Ошибка парсинга JSON: #{e.message}\n#{e.backtrace.join("\n")}"
      rescue => e
        Rails.logger.error "[RestoreUserConsumer] Необработанная ошибка: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end
