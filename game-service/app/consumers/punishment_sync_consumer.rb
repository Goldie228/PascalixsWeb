# frozen_string_literal: true

# Handles punishment synchronization events from identity-service.
# Applies bans, unbans, mutes, and unmutes to the Minecraft server
# via AuthMe and LuckPerms integration.
class PunishmentSyncConsumer < ApplicationConsumer
  def process_message(message)
    data = parse_payload(message.payload)
    return unless data

    case data[:type]
    when 'ban', 'punishment_issued'
      sync_ban(data)
    when 'unban', 'punishment_resolved'
      sync_unban(data)
    when 'mute'
      sync_mute(data)
    when 'unmute'
      sync_unmute(data)
    else
      Rails.logger.warn("[#{message.topic}] Unknown punishment type: #{data[:type].inspect}")
    end
  end

  private

  def sync_ban(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    reason = data[:reason]&.to_s || 'No reason provided'
    issuer = data[:issuer]&.to_s || 'Console'
    expires_at = data[:expires_at]
    user_id = data[:user_id]

    return if nickname.blank?

    # Ban user in AuthMe — set isLogged to 0 and mark as banned
    record = Authme.find_by(realname: nickname)
    if record
      record.update!(
        isLogged: 0,
        hasSession: 0
      )
      Rails.logger.info("✅ AuthMe: player banned (isLogged=0): nickname=#{nickname}")
    else
      Rails.logger.warn("🔍 AuthMe record not found for banned player: nickname=#{nickname}")
    end

    # Remove user from all LuckPerms groups — set primary group to 'banned'
    player = LuckpermsPlayer.find_by(username: nickname.downcase)
    if player
      player.update!(primary_group: 'banned')
      Rails.logger.info("✅ LuckPerms: player group changed to 'banned': nickname=#{nickname}")
    end

    # Clean up Redis role cache
    redis_key = "player_roles:#{nickname.downcase}"
    if defined?(REDIS_CLIENT) && REDIS_CLIENT&.exists?(redis_key)
      REDIS_CLIENT.del(redis_key)
    end

    # Clean up group cache
    group_key = "player_group:#{nickname.downcase}"
    if defined?(REDIS_CLIENT) && REDIS_CLIENT&.exists?(group_key)
      REDIS_CLIENT.del(group_key)
    end

    Rails.logger.info("✅ User banned in Minecraft server: nickname=#{nickname}, reason=#{reason}, issuer=#{issuer}")
  rescue => e
    Rails.logger.error("❌ Failed to ban user: #{e.message}")
    raise
  end

  def sync_unban(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    user_id = data[:user_id]

    return if nickname.blank?

    # Restore user in AuthMe
    record = Authme.find_by(realname: nickname)
    if record
      record.update!(
        isLogged: 0,
        hasSession: 0
      )
      Rails.logger.info("✅ AuthMe: player unbanned (session cleared): nickname=#{nickname}")
    else
      Rails.logger.warn("🔍 AuthMe record not found for unbanned player: nickname=#{nickname}")
    end

    # Restore default group in LuckPerms
    player = LuckpermsPlayer.find_by(username: nickname.downcase)
    if player
      player.update!(primary_group: 'default')
      Rails.logger.info("✅ LuckPerms: player group restored to 'default': nickname=#{nickname}")
    end

    # Set default group in Redis
    if defined?(REDIS_CLIENT)
      REDIS_CLIENT.set("player_group:#{nickname.downcase}", 'default')
    end

    Rails.logger.info("✅ User unbanned in Minecraft server: nickname=#{nickname}")
  rescue => e
    Rails.logger.error("❌ Failed to unban user: #{e.message}")
    raise
  end

  def sync_mute(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    reason = data[:reason]&.to_s || 'No reason provided'
    issuer = data[:issuer]&.to_s || 'Console'
    user_id = data[:user_id]

    return if nickname.blank?

    # Store mute status in Redis
    if defined?(REDIS_CLIENT)
      mute_data = {
        muted: true,
        reason: reason,
        issuer: issuer,
        expires_at: data[:expires_at],
        muted_at: Time.current.to_i
      }
      REDIS_CLIENT.set("player_mute:#{nickname.downcase}", mute_data.to_json)
    end

    # Add mute permission in LuckPerms (stored in Redis for quick access)
    if defined?(REDIS_CLIENT)
      REDIS_CLIENT.set("player_mute_permission:#{nickname.downcase}", 'true')
    end

    Rails.logger.info("✅ User muted in Minecraft server: nickname=#{nickname}, reason=#{reason}, issuer=#{issuer}")
  rescue => e
    Rails.logger.error("❌ Failed to mute user: #{e.message}")
    raise
  end

  def sync_unmute(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    user_id = data[:user_id]

    return if nickname.blank?

    # Remove mute status from Redis
    if defined?(REDIS_CLIENT)
      REDIS_CLIENT.del("player_mute:#{nickname.downcase}")
      REDIS_CLIENT.del("player_mute_permission:#{nickname.downcase}")
    end

    Rails.logger.info("✅ User unmuted in Minecraft server: nickname=#{nickname}")
  rescue => e
    Rails.logger.error("❌ Failed to unmute user: #{e.message}")
    raise
  end
end
