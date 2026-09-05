class ApplicationConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      handle_message(message)
    end
  end

  private

  def handle_message(message)
    Rails.logger.debug "Processing message from topic #{message.topic} partition #{message.partition}: #{message.raw_payload[0..200]}"
    process_message(message)
  end

  def process_message(message)
    # Override in child consumers
    raise NotImplementedError, "#{self.class} must implement #process_message"
  end

  def error_handler(exception, topic:, partition:, messages: [])
    Rails.logger.error "Error processing messages on topic #{topic} partition #{partition}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    # Verify Redis connection before retry
    begin
      raise Karafka::Errors::ConnectionError, 'Redis connection failed' unless REDIS_CLIENT&.ping
    rescue => redis_err
      Rails.logger.error "Redis ping failed: #{redis_err.message}"
      # Still attempt retry via Kafka
    end

    # Re-enqueue messages for retry
    messages.each do |message|
      Karafka.producer.produce_async(
        topic: topic,
        payload: message.payload,
        key: message.key
      )
    end
  end
end
