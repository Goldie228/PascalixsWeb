# frozen_string_literal: true

# Handles login and logout events from the Minecraft server.
# Updates user last login/logout timestamps and sends notifications.
class LoginEventConsumer < ApplicationConsumer
  def process_message(message)
    data = parse_payload(message.payload)
    return unless data

    case data[:event]
    when 'login', 'player_login'
      handle_login(data)
    when 'logout', 'player_logout'
      handle_logout(data)
    else
      Rails.logger.warn("[#{message.topic}] Unknown login event: #{data[:event].inspect}")
    end
  end

  private

  def handle_login(data)
    nickname = data[:nickname]&.to_s&.strip
    user_id = data[:user_id]
    ip = data[:ip]
    uuid = data[:uuid]

    return if nickname.blank?

    # Find user in AuthMe and update login info
    record = Authme.find_by(realname: nickname)
    if record
      record.update!(
        lastlogin: Time.current.to_i,
        ip: ip,
        isLogged: 1,
        hasSession: 1
      )
      Rails.logger.info("✅ AuthMe: login recorded for #{nickname} (ip=#{ip})")
    else
      # Create AuthMe record if player is not registered yet
      Authme.create!(
        realname: nickname,
        username: nickname.downcase,
        ip: ip,
        world: data[:world] || 'world',
        x: data[:x].to_f || 0.0,
        y: data[:y].to_f || 0.0,
        z: data[:z].to_f || 0.0,
        isLogged: 1,
        hasSession: 1,
        regdate: Time.current.to_i,
        lastlogin: Time.current.to_i
      )
      Rails.logger.info("✅ AuthMe: new player registered on login: #{nickname}")
    end

    # Ensure LuckPerms player record exists
    LuckpermsPlayer.find_or_create_by(username: nickname.downcase) do |player|
      player.uuid = uuid || SecureRandom.uuid
      player.primary_group = 'default'
    end

    # Load player roles into Redis
    load_player_roles(nickname)

    # Send login notification
    send_notification(user_id, 'login', 'You have logged in to the server') if user_id

    Rails.logger.info("✅ Login event processed: nickname=#{nickname}, user_id=#{user_id}, ip=#{ip}")
  rescue => e
    Rails.logger.error("❌ Failed to process login event: #{e.message}")
    raise
  end

  def handle_logout(data)
    nickname = data[:nickname]&.to_s&.strip
    user_id = data[:user_id]

    return if nickname.blank?

    # Update logout info in AuthMe
    record = Authme.find_by(realname: nickname)
    if record
      record.update!(
        isLogged: 0,
        hasSession: 0
      )
      Rails.logger.info("✅ AuthMe: logout recorded for #{nickname}")
    end

    # Clean up Redis caches
    cleanup_player_cache(nickname)

    Rails.logger.info("✅ Logout event processed: nickname=#{nickname}, user_id=#{user_id}")
  rescue => e
    Rails.logger.error("❌ Failed to process logout event: #{e.message}")
    raise
  end

  def load_player_roles(nickname)
    return unless defined?(REDIS_CLIENT)

    roles_consumer = RolesConsumer.new
    roles = roles_consumer.get_player_roles(nickname)

    if roles.present?
      roles_consumer.send_roles_to_redis(nickname, roles)
      Rails.logger.debug("🎭 Roles loaded for #{nickname}")
    else
      roles_consumer.remove_roles_from_redis(nickname)
      Rails.logger.debug("🧹 No roles found for #{nickname}")
    end
  end

  def cleanup_player_cache(nickname)
    return unless defined?(REDIS_CLIENT)

    redis_key = "player_roles:#{nickname.downcase}"
    REDIS_CLIENT.del(redis_key) if REDIS_CLIENT.exists?(redis_key)

    group_key = "player_group:#{nickname.downcase}"
    REDIS_CLIENT.del(group_key) if REDIS_CLIENT.exists?(group_key)

    mute_key = "player_mute:#{nickname.downcase}"
    REDIS_CLIENT.del(mute_key) if REDIS_CLIENT.exists?(mute_key)
  end
end
