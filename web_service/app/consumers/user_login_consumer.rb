class UserLoginConsumer < ApplicationConsumer
  def consume
    Rails.logger.info "UserLoginConsumer started consuming messages"
    messages.each do |message|
      payload = message.payload
      Rails.logger.info "Received response: #{payload.inspect}"

      handle_response(payload)
    end
  end

  private

  def handle_response(payload)
    status = payload['status']
    correlation_id = payload['correlation_id']
    user_id = payload['user_id']

    redis_key = "auth_responses:#{correlation_id}"
    response_data = { status: status, user_id: user_id }

    REDIS_CLIENT.set(redis_key, response_data.to_json, ex: 15)
    Rails.logger.info "Response saved in Redis for correlation ID: #{correlation_id} with TTL of 1 hour"
  end
end
