class ChangePasswordConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      nickname = payload[:nickname]&.strip
      hashed_password = payload[:password]&.strip
      next unless nickname && hashed_password

      account = MinecraftAccount.find_by(nickname: nickname)
      next unless account

      account.password_hash = hashed_password
      if account.save(validate: false)
        Rails.logger.info "[ChangePassword] Password updated for account=#{nickname}"
      else
        Rails.logger.error "[ChangePassword] Failed: #{account.errors.full_messages.join(', ')}"
      end
    rescue => e
      handle_error(e, nickname: payload[:nickname])
    end
  end
end
