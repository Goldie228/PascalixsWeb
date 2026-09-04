class DeletePlayerConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      begin
        payload = parse_payload(message.payload)
        next unless payload

        nickname = payload[:nickname]&.strip
        discord_id = payload[:discord_id]&.strip
        user_id = nil

        # Find by Minecraft
        if nickname.present?
          account = MinecraftAccount.find_by(nickname: nickname)
          user_id = account&.user_id
        end

        # Find by Discord if not found
        if user_id.nil? && discord_id.present?
          discord = DiscordAccount.find_by(discord_id: discord_id)
          user_id = discord&.user_id
        end

        next unless user_id

        user = User.find_by(id: user_id)

        # Revoke pass
        user&.update!(role_id: 1, is_added: false) if user

        # Add to droped_users
        DropedUser.create!(name: nickname) if nickname.present? && !DropedUser.exists?(name: nickname)

        # Delete related records
        ActiveRecord::Base.transaction do
          DiscordAccount.find_by(user_id: user_id)&.destroy
          MinecraftAccount.find_by(user_id: user_id)&.destroy
          UsersPunishment.where(user_id: user_id).destroy_all
          UsersPunishment.where(bad_user_id: user_id).destroy_all
          user&.destroy
        end

        # Clear sessions
        deleted = DeleteUserSessionService.call(user_id: user_id, nickname: nickname)

        # Delete from ClickHouse
        begin
          ClickHouse.connection.execute("ALTER TABLE users DELETE WHERE user_id = '#{user_id}'")
        rescue => e
          Rails.logger.error "[DeletePlayer] ClickHouse error: #{e.message}"
        end

        Rails.logger.info "[DeletePlayer] Cleaned up user_id=#{user_id}, sessions deleted=#{deleted}"
      rescue => e
        handle_error(e, nickname: nickname, discord_id: discord_id)
      end
    end
  end
end
