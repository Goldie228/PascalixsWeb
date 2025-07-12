class ChangePasswordMcConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      begin
        raw = message.payload["payload"] || message.payload
        if raw.nil?
          Rails.logger.warn("⚠️ Payload отсутствует: #{message.payload.inspect}")
          next
        end

        parsed =
          if raw.is_a?(String)
            JSON.parse(raw, symbolize_names: true)
          elsif raw.respond_to?(:deep_symbolize_keys)
            raw.deep_symbolize_keys
          else
            Rails.logger.warn("⚠️ Невозможно обработать payload: #{raw.inspect}")
            next
          end

        required_keys = %i[nickname password]
        missing = required_keys.reject { |k| parsed.key?(k) }

        if missing.any?
          Rails.logger.warn("⚠️ Пропущены обязательные поля: #{missing.join(', ')}")
          next
        end

        realname = parsed[:nickname].to_s.strip
        password = parsed[:password].to_s.strip

        record = Authme.find_by(realname: realname)

        if record.nil?
          Rails.logger.warn("🔍 Аккаунт не найден: realname=#{realname}")
          next
        end

        record.update!(password: password)
        Rails.logger.info("✅ Пароль обновлён в Authme: realname=#{realname}")

      rescue JSON::ParserError => e
        Rails.logger.error("🛑 Ошибка парсинга JSON: #{e.message}")
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("🛑 Ошибка валидации: #{e.message}")
      rescue => e
        Rails.logger.error("🛑 Необработанная ошибка: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
