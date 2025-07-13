class RolesConsumer < ApplicationConsumer
  ROLE_TTL_SECONDS = 3.hours.to_i

  def consume
    messages.each do |message|
      begin
        payload = message.payload["payload"]
        nickname = payload["nickname"].to_s.strip

        if nickname.blank?
          Rails.logger.warn("⚠️ Никнейм не передан в сообщении: #{payload.inspect}")
          next
        end

        Rails.logger.debug "📨 Получено сообщение: nickname=#{nickname}"

        roles = get_player_roles(nickname)

        if roles.present?
          send_roles_to_redis(nickname, roles)
        else
          remove_roles_from_redis(nickname)
          Rails.logger.info("🗑️ Удалены роли для #{nickname} — не найдены или пустые")
        end
      rescue => e
        Rails.logger.error("🛑 Ошибка при обработке сообщения: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end

  def get_player_roles(nickname)
    return nil if nickname.blank?

    uuid = LuckpermsPlayer.find_uuid_by_username(nickname.downcase)
    return nil if uuid.nil?

    prefixes = LuckpermsUserPermission.player_prefixes(uuid)
    return nil if prefixes.blank?

    translated = LuckpermsGroupPermission.translate_and_sort_prefixes(prefixes)
    return nil if translated.blank?

    LuckpermsGroup.merge_colors(translated)
  end

  def send_roles_to_redis(nickname, roles)
    redis_key = "player_roles:#{nickname.downcase}"
    REDIS_CLIENT.set(redis_key, roles.to_json, ex: ROLE_TTL_SECONDS)
    Rails.logger.info("✅ Установлены роли игроку #{nickname}, TTL=3 часа, ключ=#{redis_key}")
  end

  def remove_roles_from_redis(nickname)
    redis_key = "player_roles:#{nickname.downcase}"
    if REDIS_CLIENT.exists?(redis_key)
      REDIS_CLIENT.del(redis_key)
      Rails.logger.debug("🧹 Ключ #{redis_key} удалён из Redis")
    else
      Rails.logger.debug("🔍 Ключ #{redis_key} отсутствует в Redis — нечего удалять")
    end
  end
end
