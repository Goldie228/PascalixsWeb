class DeletePlayerConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        payload = parse_payload(message.payload)
        nickname = payload[:nickname].strip

        account = MinecraftAccount.find_by(nickname: nickname)
        unless account
          Rails.logger.warn "[DeletePlayer] ❌ Аккаунт с ником #{nickname} не найден"
          next
        end

        user_id = account.user_id
        user = User.find_by(id: user_id)

        # 1 Забираем проходку
        if user
          user.update!(role_id: 1, is_added: false)
          Rails.logger.info "[DeletePlayer] 🚫 Проходка отнята у пользователя #{user_id}"
        end

        # 2 Добавим в droped_users
        unless DropedUser.exists?(name: nickname)
          DropedUser.create!(name: nickname)
          Rails.logger.info "[DeletePlayer] 🪦 Никнейм #{nickname} добавлен в droped_users"
        else
          Rails.logger.info "[DeletePlayer] ℹ️ Никнейм #{nickname} уже присутствует в droped_users — пропущено"
        end

        # 3 Удалим связанные записи
        ActiveRecord::Base.transaction do
          DiscordAccount.find_by(user_id: user_id)&.destroy
          MinecraftAccount.find_by(user_id: user_id)&.destroy
          UsersPunishment.where(user_id: user_id).destroy_all
          UsersPunishment.where(bad_user_id: user_id).destroy_all
          user&.destroy
        end

        Rails.logger.info "[DeletePlayer] 🧼 Данные пользователя #{user_id} очищены"

        # 4 Очистим сессии
        deleted = DeleteUserSessionService.call(user_id: user_id, nickname: nickname)
        Rails.logger.info "[DeletePlayer] 🚫 Удалено #{deleted} сессий для #{user_id}"

        # 5 Удаление из ClickHouse
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
