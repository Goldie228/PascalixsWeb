class UserDataProducer
  class << self
    def publish(user)
      begin
        data = user.as_json(include: [ :discord_account, :minecraft_account ])
        data["role_name"] = user.role_name
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
      rescue => e
        Rails.logger.error "Error processing message: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end

    private

    def replace_nil_with_empty(obj)
      case obj
      when Hash
        obj.transform_values { |v| replace_nil_with_empty(v) }
      when Array
        obj.map { |e| replace_nil_with_empty(e) }
      when nil
        ""
      else
        obj
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
  end
end
