class UserDataRequestConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      user_id = payload['user_id']
      user = find_user(user_id)

      if user
        UserDataProducer.publish(user)
        Rails.logger.info "User data published: user_id=#{user_id}"
      else
        Rails.logger.warn "User not found: user_id=#{user_id}"
      end
    rescue => e
      handle_error(e, user_id: payload['user_id'])
    end
  end
end
