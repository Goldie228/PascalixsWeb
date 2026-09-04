class ChangeEmailConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      user_id = payload[:user_id]
      user = find_user(user_id)
      next unless user

      discord = DiscordAccount.find_by(user_id: user.id)
      unless discord
        Rails.logger.error "[ChangeEmail] Discord account not found for user_id=#{user_id}"
        next
      end

      new_email = payload[:email]
      if user.update(email: new_email)
        Rails.logger.info "[ChangeEmail] Email updated for user_id=#{user_id}: #{new_email}"
      else
        Rails.logger.error "[ChangeEmail] Failed to update email: #{user.errors.full_messages.join(', ')}"
      end
    rescue => e
      handle_error(e, user_id: payload[:user_id])
    end
  end
end
