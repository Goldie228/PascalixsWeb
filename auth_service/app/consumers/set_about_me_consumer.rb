class SetAboutMeConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      user_id = payload['user_id']
      user = find_user(user_id)
      next unless user

      user.update(about_me: payload['about_me'])
      Rails.logger.info "About me updated for user_id=#{user_id}"
    rescue => e
      handle_error(e, user_id: payload['user_id'])
    end
  end
end
