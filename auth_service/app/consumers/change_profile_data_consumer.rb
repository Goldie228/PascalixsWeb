class ChangeProfileDataConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        raw_payload = message.payload
        parsed_json =
          if raw_payload.is_a?(String)
            JSON.parse(raw_payload, symbolize_names: true)
          else
            raw_payload.deep_symbolize_keys
          end

        Rails.logger.debug "📨 Получено сообщение на смену профиля: #{parsed_json.inspect}"

        required_keys = [ :user_id ]
        missing = required_keys.reject { |k| parsed_json.key?(k) }

        if missing.any?
          Rails.logger.warn "⚠️ Пропущены обязательные поля: #{missing.join(', ')}"
          next
        end

        user = User.find_by(id: parsed_json[:user_id])

        if user.nil?
          Rails.logger.warn "🔍 Пользователь не найден: user_id=#{parsed_json[:user_id]}"
          next
        end

        changes = {}

        # ✉️ Email (если указан и отличается)
        if parsed_json[:email].present? && parsed_json[:email] != discord_account(user)&.email
          discord_account(user)&.update(email: parsed_json[:email])
          changes[:email] = parsed_json[:email]
        end

        # 🧵 Discord (@name или @name#0000)
        if parsed_json[:discord].present?
          minecraft_account = MinecraftAccount.find_by(user_id: user.id)
          nickname = minecraft_account&.nickname
          deleted = DeleteUserSessionService.call(user_id: user.id, nickname: nickname)

          input = parsed_json[:discord].delete_prefix("@").strip
          parts = input.split("#")
          username = parts[0]
          discriminator = parts[1]

          disc = discord_account(user)

          if disc &&
             (disc.username != username || (discriminator.present? && disc.discriminator != discriminator))
            disc.update(
              username:      username,
              discriminator: discriminator,
              discord_id:    disc.discord_id + "_change",
            )

            changes[:discord] = "@#{username}#{discriminator ? "##{discriminator}" : ""}"
            Rails.logger.info("🔁 Discord обновлён для user_id=#{user.id}: username=#{username}, discriminator=#{discriminator}, discord_id очищен")
          end
        end

        # ✅ Проходка (pass: true/false → is_added + role_id)
        unless parsed_json[:pass].nil?
          pass_bool = ActiveModel::Type::Boolean.new.cast(parsed_json[:pass])
          if user.is_added != pass_bool
            user.is_added = pass_bool
            user.role_id = pass_bool ? 2 : 1
            changes[:pass_access] = pass_bool
          end
        end

        if changes.any?
          user.save! if user.changed?
          Rails.logger.info "✅ Обновлён профиль: user_id=#{user.id}, изменения: #{changes.inspect}"
        else
          Rails.logger.debug "🔍 Нет изменений для user_id=#{user.id}"
        end

      rescue JSON::ParserError => e
        Rails.logger.error "🛑 Ошибка парсинга JSON: #{e.message}\n#{e.backtrace.join("\n")}"
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "🛑 Ошибка сохранения: #{e.message}"
      rescue => e
        Rails.logger.error "🛑 Необработанная ошибка: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end

  private

  def discord_account(user)
    DiscordAccount.find_by(user_id: user.id)
  end
end
