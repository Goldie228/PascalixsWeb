# frozen_string_literal: true

# Handles skin synchronization events.
# Processes skin updates and resets for players on the Minecraft server.
# Skin data is stored in Redis for quick access by the Minecraft server.
class SkinSyncConsumer < ApplicationConsumer
  def process_message(message)
    data = parse_payload(message.payload)
    return unless data

    case data[:action]
    when 'update'
      sync_skin_update(data)
    when 'reset'
      sync_skin_reset(data)
    else
      Rails.logger.warn("[#{message.topic}] Unknown skin action: #{data[:action].inspect}")
    end
  end

  private

  def sync_skin_update(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    skin_url = data[:skin_url]&.to_s&.strip
    user_id = data[:user_id]

    return if nickname.blank?
    return if skin_url.blank?

    # Store skin URL in Redis for quick access
    if defined?(REDIS_CLIENT)
      skin_data = {
        url: skin_url,
        updated_at: Time.current.to_i,
        user_id: user_id
      }
      REDIS_CLIENT.set("player_skin:#{nickname.downcase}", skin_data.to_json)
    end

    # Send confirmation notification
    send_notification(user_id, 'skin', 'Your skin has been updated!') if user_id

    Rails.logger.info("✅ Skin updated for player: nickname=#{nickname}")
  rescue => e
    Rails.logger.error("❌ Failed to update skin: #{e.message}")
    raise
  end

  def sync_skin_reset(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    user_id = data[:user_id]

    return if nickname.blank?

    # Remove skin from Redis cache
    if defined?(REDIS_CLIENT)
      REDIS_CLIENT.del("player_skin:#{nickname.downcase}")
    end

    # Send confirmation notification
    send_notification(user_id, 'skin', 'Your skin has been reset to default!') if user_id

    Rails.logger.info("✅ Skin reset for player: nickname=#{nickname}")
  rescue => e
    Rails.logger.error("❌ Failed to reset skin: #{e.message}")
    raise
  end
end
