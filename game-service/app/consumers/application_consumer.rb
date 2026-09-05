# frozen_string_literal: true

# Application consumer from which all Karafka consumers should inherit
# Provides shared error handling, retry logic, and logging for all game-service consumers.
class ApplicationConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      handle_message(message)
    end
  end

  private

  def handle_message(message)
    Rails.logger.debug "[#{message.topic}] Processing message: #{message.raw_payload}"
    process_message(message)
    Rails.logger.debug "[#{message.topic}] Message processed successfully"
  rescue => e
    handle_consumer_error(e, message)
    raise
  end

  def process_message(message)
    # Override in child consumers
  end

  def handle_consumer_error(exception, message)
    Rails.logger.error "[#{message.topic}] Error processing message: #{exception.message}"
    Rails.logger.error "[#{message.topic}] #{exception.backtrace&.first(10)&.join("\n")}"

    # Verify Redis connectivity for retry
    unless redis_available?
      Rails.logger.error "[#{message.topic}] Redis unavailable — cannot retry"
      return
    end

    # Re-enqueue message for retry
    Karafka.producer.produce_async(
      topic: message.topic,
      payload: message.payload,
      key: message.key
    )
    Rails.logger.info "[#{message.topic}] Message re-enqueued for retry"
  end

  def redis_available?
    return true if defined?(REDIS_CLIENT) && REDIS_CLIENT&.ping

    false
  rescue StandardError
    false
  end

  def parse_payload(payload)
    raw = payload["payload"] || payload
    return nil if raw.nil?

    if raw.is_a?(String)
      JSON.parse(raw, symbolize_names: true)
    elsif raw.respond_to?(:deep_symbolize_keys)
      raw.deep_symbolize_keys
    else
      Rails.logger.warn("⚠️ Невозможно обработать payload: #{raw.inspect}")
      nil
    end
  end

  def find_authme_by_nickname(nickname)
    return nil if nickname.blank?
    Authme.find_by(realname: nickname.strip)
  end

  def find_authme_by_username(username)
    return nil if username.blank?
    Authme.find_by(username: username.strip)
  end

  def find_luckperms_player_by_username(username)
    return nil if username.blank?
    LuckpermsPlayer.find_by(username: username.downcase)
  end

  def send_notification(user_id, type, message)
    ApplicationProducer.produce_async(
      topic: 'notification.push',
      payload: {
        user_id: user_id,
        type: type,
        message: message
      }.to_json
    )
  rescue => e
    Rails.logger.error "Failed to send notification: #{e.message}"
  end
end
