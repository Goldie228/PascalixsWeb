class ChangePasswordConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        raw_payload = message.payload
        parsed_json = raw_payload.is_a?(String) ? JSON.parse(raw_payload, symbolize_names: true) : raw_payload.deep_symbolize_keys

        Rails.logger.debug "📨 Получено сообщение на смену пароля: #{parsed_json.inspect}"

        required_keys = [ :nickname, :password ]
        missing = required_keys.reject { |k| parsed_json.key?(k) }

        if missing.any?
          Rails.logger.warn "⚠️ Пропущены обязательные поля: #{missing.join(', ')}"
          next
        end

        nickname        = parsed_json[:nickname].strip
        hashed_password = parsed_json[:password].strip

        account = MinecraftAccount.find_by(nickname: nickname)

        if account.nil?
          Rails.logger.warn "❌ MinecraftAccount не найден для nickname=#{nickname}"
          next
        end

        # 🔒 Обновление password_hash напрямую (хеш уже пришёл)
        account.password_hash = hashed_password

        # ⛔ Пропускаем password-related валидации — сохраняем без них
        if account.save(validate: false)
          Rails.logger.info "✅ Пароль обновлён для MinecraftAccount=#{nickname}"
        else
          Rails.logger.error "❌ Ошибка сохранения аккаунта: #{account.errors.full_messages.join(', ')}"
        end

      rescue JSON::ParserError => e
        Rails.logger.error "🛑 Ошибка парсинга JSON: #{e.message}\n#{e.backtrace.join("\n")}"
      rescue => e
        Rails.logger.error "🛑 Необработанная ошибка: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end
