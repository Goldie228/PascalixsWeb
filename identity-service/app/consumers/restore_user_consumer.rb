class RestoreUserConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      nickname = payload[:nickname]&.strip
      next unless nickname

      if DropedUser.exists?(name: nickname)
        DropedUser.where(name: nickname).delete_all
        Rails.logger.info "[RestoreUser] Player #{nickname} restored"
      else
        Rails.logger.warn "[RestoreUser] Player #{nickname} not found in droped_users"
      end
    rescue => e
      handle_error(e, nickname: payload[:nickname])
    end
  end
end
