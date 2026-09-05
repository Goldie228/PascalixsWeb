class UnifiedSocialUnbindConsumer < ApplicationConsumer
  SOCIAL_UNBIND_CONFIG = {
    'identity.social.unbind.tiktok' => { fields: %i[tiktok_channel_name tiktok_url] },
    'identity.social.unbind.twitch' => { fields: %i[twitch_channel_name twitch_url] },
    'identity.social.unbind.youtube' => { fields: %i[youtube_channel_name youtube_url] }
  }.freeze

  def consume
    messages.each do |message|
      begin
        payload = parse_payload(message.payload)
        next unless payload

        user_id = payload['user_id'] || payload[:user_id]
        next unless user_id

        user = find_user(user_id)
        next unless user

        config = SOCIAL_UNBIND_CONFIG[message.topic]
        next unless config

        attrs = config[:fields].each_with_object({}) do |field, hash|
          hash[field] = nil
        end

        user.update!(attrs)
        Rails.logger.info "Social unbind: user_id=#{user_id} topic=#{message.topic}"
      rescue => e
        handle_error(e, topic: message.topic)
      end
    end
  end
end
