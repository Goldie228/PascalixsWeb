class MinecraftRegistrationConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      begin
        raw_payload = message.payload
        payload = raw_payload.is_a?(String) ? JSON.parse(raw_payload, symbolize_names: true) : raw_payload
        payload = payload['payload'] || payload

        correlation_id = payload['correlation_id']
        user_id = payload['user_id']
        locale = payload['locale']
        nickname = payload['nickname']
        password = payload['password']
        password_confirmation = payload['password_confirmation']

        I18n.locale = locale
        user = User.find(user_id)

        account = user.build_minecraft_account(
          nickname:, password:, password_confirmation:
        )

        if account.save
          send_response(correlation_id, :success)
          UserDataProducer.publish(user)
          produce_with_retries('minecraft_service_get_roles', { nickname: }.to_json)
        else
          formatted_errors = account.errors.messages.each_with_object({}) do |(field, msgs), hash|
            hash[field] = msgs.first
          end
          send_response(correlation_id, :error, errors: formatted_errors)
        end
      rescue ActiveRecord::RecordNotFound => e
        send_response(correlation_id, :error, errors: { user: [I18n.t('errors.user_not_found')] })
      rescue => e
        handle_error(e, correlation_id: correlation_id)
      end
    end
  end

  private

  def send_response(correlation_id, status, payload: nil, errors: {})
    response = {
      correlation_id:,
      status: status.to_s,
      timestamp: Time.current.iso8601
    }
    response[:payload] = payload if payload
    response[:errors] = errors if errors.any?

    redis_key = "registration_responses:#{correlation_id}"
    REDIS_CLIENT.set(redis_key, response.to_json, ex: 3600)
  end
end
