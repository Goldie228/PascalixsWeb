class RegistrationResponseJob < ApplicationJob
  queue_as :default

  def perform(correlation_id, user_id)
    response = wait_for_response(correlation_id)

    unless response.nil?
      Rails.logger.info "response: #{response}"
      broadcast_response(user_id, response)
    end
  ensure
    REDIS_CLIENT.del("registration_responses:#{correlation_id}")
  end

  private

  def wait_for_response(correlation_id)
    start_time = Time.now
    timeout = 15.seconds

    loop do
      response_str = REDIS_CLIENT.get("registration_responses:#{correlation_id}")
      return JSON.parse(response_str) if response_str.present?
      break if Time.now - start_time > timeout
      sleep 1
    end
  end

  def broadcast_response(user_id, response)
    message = { response: response.deep_transform_keys { |k| k.to_s.camelize(:lower) } }
    Rails.logger.info "message: #{message}, user_id: #{user_id}"
    ActionCable.server.broadcast("registration_channel_#{user_id}", message)
  end
end
