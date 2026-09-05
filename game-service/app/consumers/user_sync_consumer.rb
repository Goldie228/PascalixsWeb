# frozen_string_literal: true

# Handles user synchronization events from identity-service.
# Processes user create, update, and delete actions to keep
# the Minecraft server (AuthMe + LuckPerms) in sync with the identity service.
class UserSyncConsumer < ApplicationConsumer
  def process_message(message)
    data = parse_payload(message.payload)
    return unless data

    case data[:action]
    when 'create'
      sync_user_creation(data)
    when 'update'
      sync_user_update(data)
    when 'delete'
      sync_user_deletion(data)
    else
      Rails.logger.warn("[#{message.topic}] Unknown sync action: #{data[:action].inspect}")
    end
  end

  private

  def sync_user_creation(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    discord_id = data[:discord_id]&.to_s
    user_id = data[:user_id]

    return if nickname.blank?

    # Register user in AuthMe
    Authme.find_or_create_by(realname: nickname) do |record|
      record.username = nickname.downcase
      record.world = 'world'
      record.x = 0.0
      record.y = 0.0
      record.z = 0.0
      record.regdate = Time.current.to_i
    end

    # Ensure player exists in LuckPerms
    LuckpermsPlayer.find_or_create_by(username: nickname.downcase) do |record|
      record.uuid = SecureRandom.uuid
      record.primary_group = 'default'
    end

    # Set default group in LuckPerms
    set_luckperms_group(nickname, 'default')

    # Send confirmation notification
    send_notification(user_id, 'sync', 'Your Minecraft account has been synced!') if user_id

    Rails.logger.info("✅ User synced with Minecraft server: nickname=#{nickname}, user_id=#{user_id}")
  rescue => e
    Rails.logger.error("❌ Failed to sync user creation: #{e.message}")
    raise
  end

  def sync_user_update(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    old_nickname = data[:old_nickname]&.to_s&.strip
    discord_id = data[:discord_id]&.to_s
    user_id = data[:user_id]

    return if nickname.blank?

    # Update AuthMe record
    record = Authme.find_by(realname: old_nickname) if old_nickname.present?
    record ||= Authme.find_by(realname: nickname)

    if record
      record.update!(realname: nickname, username: nickname.downcase) if old_nickname.present? && record.realname != nickname
      Rails.logger.info("✅ AuthMe updated: realname=#{record.realname}")
    else
      # Create new record if it doesn't exist
      Authme.find_or_create_by(realname: nickname) do |r|
        r.username = nickname.downcase
        r.world = 'world'
        r.x = 0.0
        r.y = 0.0
        r.z = 0.0
        r.regdate = Time.current.to_i
      end
    end

    # Update LuckPerms player
    if old_nickname.present? && old_nickname != nickname
      old_player = LuckpermsPlayer.find_by(username: old_nickname.downcase)
      old_player&.update!(username: nickname.downcase) if old_player
    end

    LuckpermsPlayer.find_or_create_by(username: nickname.downcase) do |record|
      record.uuid = SecureRandom.uuid
      record.primary_group = 'default'
    end

    send_notification(user_id, 'sync', 'Your Minecraft nickname has been updated!') if user_id

    Rails.logger.info("✅ User updated in Minecraft server: nickname=#{nickname}, user_id=#{user_id}")
  rescue => e
    Rails.logger.error("❌ Failed to sync user update: #{e.message}")
    raise
  end

  def sync_user_deletion(data)
    nickname = data[:minecraft_nickname]&.to_s&.strip
    user_id = data[:user_id]

    return if nickname.blank?

    # Remove from AuthMe
    Authme.where(realname: nickname).delete_all
    Authme.where(username: nickname.downcase).delete_all

    # Remove from LuckPerms
    LuckpermsPlayer.where(username: nickname.downcase).delete_all

    # Clean up Redis roles cache
    redis_key = "player_roles:#{nickname.downcase}"
    if defined?(REDIS_CLIENT) && REDIS_CLIENT&.exists?(redis_key)
      REDIS_CLIENT.del(redis_key)
    end

    send_notification(user_id, 'sync', 'Your Minecraft account has been removed!') if user_id

    Rails.logger.info("✅ User removed from Minecraft server: nickname=#{nickname}, user_id=#{user_id}")
  rescue => e
    Rails.logger.error("❌ Failed to sync user deletion: #{e.message}")
    raise
  end

  def set_luckperms_group(nickname, group)
    # Store group info in Redis for quick access
    # The actual LuckPerms API would be called via HTTP to the Minecraft server
    redis_key = "player_group:#{nickname.downcase}"
    if defined?(REDIS_CLIENT)
      REDIS_CLIENT.set(redis_key, group)
    end
    Rails.logger.debug("Set group '#{group}' for player #{nickname}")
  end
end
