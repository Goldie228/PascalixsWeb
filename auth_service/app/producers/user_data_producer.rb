class UserDataProducer
  class << self
    def publish(user)
      begin
        data = user.as_json(include: [ :discord_account, :minecraft_account ])
        data["role_name"]  = user.role_name
        data["role_color"] = user.role_color
        data.delete("role_id")

        Rails.logger.debug "Processing: #{data}"

        user_id = data["user_id"] || data.dig("discord_account", "user_id") || data.dig("minecraft_account", "user_id")

        unless user_id
          Rails.logger.warn "Skipping message without user_id"
          return
        end

        safe_data = replace_nil_with_empty(data)

        store_in_redis(user_id, safe_data)
        upsert_to_clickhouse(user)
        begin
          ClickHouse.connection.execute("OPTIMIZE TABLE users FINAL")
          Rails.logger.info "[Admin] ✅ ClickHouse таблица оптимизирована (дубликаты устранены)"
        rescue => e
          Rails.logger.error "[Admin] ❌ Ошибка при оптимизации таблицы: #{e.message}"
        end
      rescue => e
        Rails.logger.error "Error processing message: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end

    private

    def replace_nil_with_empty(obj)
      case obj
      when Hash  then obj.transform_values { |v| replace_nil_with_empty(v) }
      when Array then obj.map { |e| replace_nil_with_empty(e) }
      when nil   then ""
      else obj
      end
    end

    def store_in_redis(user_id, data)
      new_event_hash = Digest::MD5.hexdigest(data.to_json)

      user_key = "user_updates:#{user_id}"
      existing_updates = REDIS_CLIENT.hgetall(user_key)
      if existing_updates.present?
        latest_timestamp = existing_updates.keys.map(&:to_i).max.to_s
        latest_event = JSON.parse(existing_updates[latest_timestamp]) rescue {}
        old_event_hash = Digest::MD5.hexdigest(latest_event.to_json)
        return if new_event_hash == old_event_hash
      end

      timestamp = (Time.now.to_f * 1000).to_i
      REDIS_CLIENT.hset(user_key, timestamp, data.to_json)
      REDIS_CLIENT.expire(user_key, 3.hour.to_i)
    rescue => e
      Rails.logger.error "Redis error: #{e.message}"
      raise
    end

    def upsert_to_clickhouse(user)
      dc     = user.discord_account
      mc     = user.minecraft_account
      pun    = user.issued_punishments.where(active: true)
      status = determine_punishment_status(pun)

      record = {
        user_id:            user.id.to_s,
        discord_username:   format_discord_name(dc),
        minecraft_nickname: mc&.nickname.to_s,
        is_added:           user.is_added ? 1 : 0,
        punishment_status:  status,
        role_id:            user.role_id.to_i,
        discord_avatar_url: dc&.avatar.to_s,
        updated_at: (Time.now.to_f * 1000).to_i
      }

      # Не забудем обновить для игроков, которые смотрят профиль
      nickname = mc.nickname
      Rails.logger.info nickname
      REDIS_CLIENT.del("public_profile:#{nickname}")

      ClickHouse.connection.insert("users", [ record ])
    rescue => e
      Rails.logger.error "❌ ClickHouse insert error: #{e.message}"
    end

    def determine_punishment_status(active_punishments)
      return 1 if active_punishments.empty?
      types = active_punishments.pluck(:type)
      return 3 if types.include?("ban")
      return 2 if types.include?("mute")
      1
    end

    def format_discord_name(dc)
      return "" unless dc
      dc.discriminator.present? ? "#{dc.username}##{dc.discriminator}" : dc.username
    rescue => e
      Rails.logger.warn "Ошибка при форматировании Discord-имени: #{e.message}"
      ""
    end
  end
end
