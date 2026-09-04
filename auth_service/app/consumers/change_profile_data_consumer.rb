class ChangeProfileDataConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      user_id = payload[:user_id]
      user = find_user(user_id)
      next unless user

      changes = {}

      # Email
      if payload[:email].present?
        discord = DiscordAccount.find_by(user_id: user.id)
        if discord && payload[:email] != discord.email
          discord.update(email: payload[:email])
          changes[:email] = payload[:email]
        end
      end

      # Discord
      if payload[:discord].present?
        mc = MinecraftAccount.find_by(user_id: user.id)
        nickname = mc&.nickname
        DeleteUserSessionService.call(user_id: user.id, nickname: nickname) if nickname

        input = payload[:discord].delete_prefix('@').strip
        parts = input.split('#')
        username = parts[0]
        discriminator = parts[1]

        disc = DiscordAccount.find_by(user_id: user.id)
        if disc && (disc.username != username || (discriminator.present? && disc.discriminator != discriminator))
          disc.update(
            username: username,
            discriminator: discriminator,
            discord_id: "#{disc.discord_id}_change"
          )
          changes[:discord] = "@#{username}#{discriminator ? "##{discriminator}" : ''}"
        end
      end

      # Pass
      if payload[:pass].present?
        pass_bool = ActiveModel::Type::Boolean.new.cast(payload[:pass])
        if user.is_added != pass_bool
          user.is_added = pass_bool
          user.role_id = pass_bool ? 2 : 1
          changes[:pass_access] = pass_bool
        end
      end

      # Sponsor
      if payload[:sponsor].present?
        sponsor_bool = ActiveModel::Type::Boolean.new.cast(payload[:sponsor])
        if user.is_sponsor != sponsor_bool
          user.is_sponsor = sponsor_bool
          changes[:sponsor] = sponsor_bool
        end
      end

      user.save! if user.changed?
      Rails.logger.info "[ChangeProfile] Updated user_id=#{user_id}, changes: #{changes.inspect}" if changes.any?
    rescue => e
      handle_error(e, user_id: payload[:user_id])
    end
  end
end
