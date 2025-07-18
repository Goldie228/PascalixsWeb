class DeletePlayerConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        payload = parse_payload(message.payload)
        nickname    = payload[:nickname]&.strip
        discord_id  = payload[:discord_id]&.strip

        user_id = nil

        # 1. Попробуем найти по Minecraft
        if nickname.present?
          account = MinecraftAccount.find_by(nickname: nickname)

          if account
            user_id = account.user_id
          else
            Rails.logger.warn "[DeletePlayer] ⚠️ Minecraft-аккаунт с ником #{nickname} не найден"
          end
        end

        # 2. Если не найден — ищем по Discord ID
        if user_id.nil? && discord_id.present?
          discord = DiscordAccount.find_by(discord_id: discord_id)
          if discord
            user_id = discord.user_id
            Rails.logger.info "[DeletePlayer] 🔄 Пользователь найден по Discord ID #{discord_id}"
          else
            Rails.logger.warn "[DeletePlayer] ❌ Discord-аккаунт с ID #{discord_id} не найден"
          end
        end

        # 3. Если пользователь не найден вообще — пропускаем
        unless user_id
          Rails.logger.warn "[DeletePlayer] 🚫 Пользователь не найден ни по nickname, ни по Discord ID — пропущено"
          return
        end

        user = User.find_by(id: user_id)

        # 4 Забираем проходку
        if user
          user.update!(role_id: 1, is_added: false)
          Rails.logger.info "[DeletePlayer] 🚫 Проходка отнята у пользователя #{user_id}"
        end

        # 5 Добавим в droped_users
        if nickname.present?
          unless DropedUser.exists?(name: nickname)
            DropedUser.create!(name: nickname)
            Rails.logger.info "[DeletePlayer] 🪦 Никнейм #{nickname} добавлен в droped_users"
          else
            Rails.logger.info "[DeletePlayer] ℹ️ Никнейм #{nickname} уже присутствует в droped_users — пропущено"
          end
        end

        # 6 Удалим связанные записи
        ActiveRecord::Base.transaction do
          DiscordAccount.find_by(user_id: user_id)&.destroy
          MinecraftAccount.find_by(user_id: user_id)&.destroy
          UsersPunishment.where(user_id: user_id).destroy_all
          UsersPunishment.where(bad_user_id: user_id).destroy_all
          user&.destroy
        end

        Rails.logger.info "[DeletePlayer] 🧼 Данные пользователя #{user_id} очищены"

        # 7 Очистим сессии
        deleted = DeleteUserSessionService.call(user_id: user_id, nickname: nickname)
        Rails.logger.info "[DeletePlayer] 🚫 Удалено #{deleted} сессий для #{user_id}"

        # 8 Удаление из ClickHouse
        begin
          # Пример чистого SQL через ClickhouseClient
          ClickHouse.connection.execute <<~SQL
            ALTER TABLE users DELETE WHERE user_id = '#{user_id}'
          SQL

          Rails.logger.info "[DeletePlayer] 🗑️ Пользователь #{user_id} удалён из ClickHouse (users)"
        rescue => e
          Rails.logger.error "[DeletePlayer] ⚠️ Ошибка при удалении из ClickHouse: #{e.message}"
        end
      rescue JSON::ParserError => e
        Rails.logger.error "🛑 Ошибка JSON: #{e.message}"
      rescue => e
        Rails.logger.error "🛑 Ошибка при удалении: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end

  private

  def parse_payload(payload)
    if payload.is_a?(String)
      JSON.parse(payload, symbolize_names: true)
    else
      payload.deep_symbolize_keys
    end
  end
end
