class WebEventsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = parse_payload(message.payload)
      next unless payload

      event_type = payload['event_type']
      user_id = payload['user_id']

      with_deduplication("web_event:#{user_id}:#{event_type}:#{payload['timestamp']}") do
        case event_type
        when 'page_viewed'
          Rails.logger.info "Page viewed: user_id=#{user_id} page=#{payload['page_path']}"
        when 'user_action'
          Rails.logger.info "User action: user_id=#{user_id} action=#{payload['action_type']}"
        when 'error_occurred'
          Rails.logger.error "Frontend error: user_id=#{user_id} type=#{payload['error_type']} msg=#{payload['error_message']}"
        when 'performance_metric'
          Rails.logger.info "Perf metric: user_id=#{user_id} metric=#{payload['metric_name']}"
        else
          Rails.logger.info "Unknown event: #{event_type}"
        end
      end
    rescue => e
      handle_error(e)
    end
  end

  private

  def with_deduplication(key)
    return unless REDIS_CLIENT.set(key, '1', nx: true, ex: 300)
    yield
  end
end
