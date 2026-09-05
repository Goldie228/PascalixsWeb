class UserLoginConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = parse_payload(message.payload)
      next unless data

      correlation_id = data['correlation_id']
      nickname = data['nickname']
      password = data['password']

      account = MinecraftAccount.find_by(nickname: nickname)
      unless account
        publish_login_result(correlation_id, false)
        next
      end

      if account.authenticate(password)
        publish_login_result(correlation_id, true, account.user.id)
        UserDataProducer.publish(account.user)
      else
        publish_login_result(correlation_id, false)
      end
    rescue => e
      handle_error(e, correlation_id: correlation_id)
      publish_login_result(correlation_id, false)
    end
  end

  private

  def publish_login_result(correlation_id, success, user_id = nil)
    payload = { status: success ? 'auth' : 'not auth', user_id: user_id }.to_json
    topic = "auth_responses:#{correlation_id}"
    REDIS_CLIENT.publish(topic, payload)
    level = success ? :info : :warn
    Rails.logger.log(level) "[UserLogin] #{success ? 'Success' : 'Failed'}: correlation_id=#{correlation_id}"
  end
end
