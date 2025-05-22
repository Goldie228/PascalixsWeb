class RolesConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      begin
        payload = message.payload["payload"]

        Rails.logger.debug "Получено сообщение: #{payload}"

        nickname = payload["nickname"]

        roles = get_player_roles(nickname)

        if roles.present?
          send_roles_to_redis(nickname, roles)
        else
          Rails.logger.info("Роли для #{nickname} не найдены или пустые")
        end
      rescue StandardError => e
        Rails.logger.error("Ошибка при обработке сообщения: #{e.message}")
      end
    end
  end

  def get_player_roles(nickname)
    return nil if nickname.nil? || nickname.strip.empty?

    nickname = nickname.downcase

    uuid = LuckpermsPlayer.find_uuid_by_username(nickname)
    return nil if uuid.nil?

    prefixes = LuckpermsUserPermission.player_prefixes(uuid)
    return nil if prefixes.nil? || prefixes.empty?

    t_prefixes = LuckpermsGroupPermission.translate_and_sort_prefixes(prefixes)
    return nil if t_prefixes.nil? || t_prefixes.empty?

    res_prefixes = LuckpermsGroup.merge_colors(t_prefixes)
    return nil if res_prefixes.nil? || res_prefixes.empty?

    res_prefixes
  end

  def send_roles_to_redis(nickname, roles)
    redis_key = "player_roles:#{nickname}"
    REDIS_CLIENT.set(redis_key, roles.to_json)
    Rails.logger.info("Сохранены роли игрока #{nickname} в Redis по ключу #{redis_key}")
  end
end
