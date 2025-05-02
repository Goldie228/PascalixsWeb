class RegistrationResponseConsumer < ApplicationConsumer
  def consume
    Rails.logger.info "RegistrationResponseConsumer started consuming messages"
    messages.each do |message|
      begin
        payload = message.payload
        Rails.logger.info "Received response: #{payload.inspect}"

        handle_response(payload)
      rescue JSON::ParserError => e
        Rails.logger.error "JSON parsing error: #{e.message}"
      end
    end
  end

  private

  def handle_response(payload)
    correlation_id = payload['correlation_id']
    return unless correlation_id

    status = payload['status']
    errors = payload['errors'] || {}

    redis_key = "registration_responses:#{correlation_id}"
    response_data = { status: status, errors: errors.transform_values(&:first) }
    
    REDIS_CLIENT.set(redis_key, response_data.to_json, ex: 1.hour) # Устанавливаем TTL в одной операции
    Rails.logger.info "Response saved in Redis for correlation ID: #{correlation_id} with TTL of 1 hour"
  end
end
