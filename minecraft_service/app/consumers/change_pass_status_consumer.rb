class ChangePassStatusConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      begin
        raw = message.payload["payload"] || message.payload
        next if raw.nil?

        parsed =
          if raw.is_a?(String)
            JSON.parse(raw, symbolize_names: true)
          elsif raw.respond_to?(:deep_symbolize_keys)
            raw.deep_symbolize_keys
          else
            Rails.logger.warn("⚠️ Невозможно обработать payload: #{raw.inspect}")
            next
          end

        required_keys = %i[nickname pass]
        missing = required_keys.reject { |k| parsed.key?(k) }

        if missing.any?
          Rails.logger.warn("⚠️ Пропущены обязательные поля: #{missing.join(', ')}")
          next
        end

        nickname   = parsed[:nickname].to_s.strip
        pass_value = ActiveModel::Type::Boolean.new.cast(parsed[:pass])
        hash       = parsed[:password]

        if nickname.blank?
          Rails.logger.warn("⚠️ Никнейм пустой")
          next
        end

        if pass_value
          if hash.blank?
            Rails.logger.warn("⚠️ Требуется хеш пароля для добавления, но он пуст")
            next
          end

          record = Authme.find_or_initialize_by(realname: nickname)
          record.username  = nickname.downcase
          record.password  = hash
          record.world     = "world"
          record.x         = 0.0
          record.y         = 0.0
          record.z         = 0.0
          record.regdate   = Time.current.to_i

          record.save!

          Rails.logger.info("✅ Игрок добавлен в Authme: #{nickname}")
        else
          deleted = Authme.where(realname: nickname).delete_all
          if deleted.positive?
            Rails.logger.info("🗑️ Игрок удалён из Authme: #{nickname}")
          else
            Rails.logger.warn("🔍 Игрок #{nickname} не найден в Authme для удаления")
          end
        end

        roles_consumer = RolesConsumer.new
        roles = roles_consumer.get_player_roles(nickname)

        if roles.present?
          roles_consumer.send_roles_to_redis(nickname, roles)
          Rails.logger.info("🎭 Роли обновлены после изменения проходки для #{nickname}")
        else
          roles_consumer.remove_roles_from_redis(nickname)
          Rails.logger.info("🧹 Роли удалены после удаления проходки для #{nickname}")
        end
      rescue JSON::ParserError => e
        Rails.logger.error("🛑 Ошибка парсинга JSON: #{e.message}")
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("🛑 Ошибка записи: #{e.message}")
      rescue => e
        Rails.logger.error("🛑 Необработанная ошибка: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
