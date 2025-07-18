class ChangeEmailConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        raw_payload = message.payload

        parsed = raw_payload.is_a?(String) ? JSON.parse(raw_payload, symbolize_names: true) : raw_payload.deep_symbolize_keys

        Rails.logger.debug "📨 [ChangeEmail] Payload: #{parsed.inspect}"

        user = User.find_by(id: parsed[:user_id])
        unless user
          Rails.logger.error "❌ [ChangeEmail] Пользователь не найден: #{parsed[:user_id]}"
          next
        end

        discord_account = DiscordAccount.find_by(user_id: user.id)
        unless discord_account
          Rails.logger.error "❌ [ChangeEmail] Discord-аккаунт не найден для пользователя #{user.id}"
          next
        end

        new_email = parsed[:email]
        user.email = new_email

        if user.save
          Rails.logger.info "✅ Email обновлён для пользователя #{user.id}: #{new_email}"
        else
          Rails.logger.error "❌ Ошибка сохранения email: #{user.errors.full_messages.join(', ')}"
        end

      rescue JSON::ParserError => e
        Rails.logger.error "🛑 [ChangeEmail] Ошибка JSON: #{e.message}"
      rescue => e
        Rails.logger.error "🛑 [ChangeEmail] Необработанная ошибка: #{e.message}"
      end
    end
  end
end
