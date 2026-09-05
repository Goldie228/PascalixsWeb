class UserSyncConsumer < ApplicationConsumer
  REQUIRED_KEYS = %i[action discord_id].freeze

  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      unless validate_required_keys(payload, REQUIRED_KEYS)
        next
      end

      action = payload[:action]&.to_s

      case action
      when 'create', 'register'
        sync_user_creation(payload)
      when 'update', 'profile_updated'
        sync_user_update(payload)
      when 'delete', 'remove'
        sync_user_deletion(payload)
      else
        Rails.logger.warn "[UserSync] Unknown sync action: #{action}"
      end
    rescue => e
      handle_error(e, action: payload[:action], discord_id: payload[:discord_id])
    end
  end

  private

  def sync_user_creation(payload)
    discord_id = payload[:discord_id]
    user = User.joins(:discord_account).find_by(discord_accounts: { user_id: discord_id })
    return unless user

    sync_with_game_service(user, action: 'create', payload: payload)
    Rails.logger.info "[UserSync] User #{user.id} creation synced"
  end

  def sync_user_update(payload)
    discord_id = payload[:discord_id]
    user = User.joins(:discord_account).find_by(discord_accounts: { user_id: discord_id })
    return unless user

    # Update user fields if provided
    update_attrs = {}
    update_attrs[:minecraft_nickname] = payload[:minecraft_nickname] if payload[:minecraft_nickname]
    update_attrs[:about_me] = payload[:about_me] if payload[:about_me]

    if update_attrs.any?
      safe_update(user, update_attrs)
    end

    sync_with_game_service(user, action: 'update', payload: payload)
    Rails.logger.info "[UserSync] User #{user.id} update synced"
  end

  def sync_user_deletion(payload)
    discord_id = payload[:discord_id]
    user = User.joins(:discord_account).find_by(discord_accounts: { user_id: discord_id })
    return unless user

    # Remove from game service first
    begin
      game_url = ENV.fetch('GAME_SERVICE_URL', 'http://localhost:3001')
      HTTParty.delete(
        "#{game_url}/api/v1/minecraft/users/#{user.id}",
        timeout: 10
      )
    rescue => e
      Rails.logger.error "[UserSync] Failed to remove user #{user.id} from game service: #{e.message}"
    end

    # Delete user
    user.destroy
    Rails.logger.info "[UserSync] User #{user.id} deleted and removed from game service"
  end

  def sync_with_game_service(user, action:, payload:)
    game_url = ENV.fetch('GAME_SERVICE_URL', 'http://localhost:3001')
    endpoint = case action
               when 'create'
                 "/api/v1/minecraft/sync"
               when 'update'
                 "/api/v1/minecraft/users/#{user.id}"
               else
                 nil
               end

    return unless endpoint

    body = {
      nickname: user.minecraft_account&.nickname,
      discord_id: user.discord_account&.user_id,
      payload: payload
    }.compact_blank.to_json

    begin
      HTTParty.send(
        action == 'create' ? :post : :put,
        "#{game_url}#{endpoint}",
        body: body,
        headers: { 'Content-Type' => 'application/json' },
        timeout: 10
      )
    rescue => e
      Rails.logger.error "[UserSync] Failed to sync user #{user.id} with game service: #{e.message}"
    end
  end
end
