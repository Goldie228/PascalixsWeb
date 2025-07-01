class UserTikTokUnbindConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      begin
        raw_payload = message.payload
        payload = JSON.parse(raw_payload["payload"].to_json) rescue nil

        user_id = payload["user_id"]

        user = User.find_by(id: user_id)
        unless user
          Rails.logger.error "Пользователь с id #{user_id} не найден"
          next
        end

        user.update!(
          tiktok_channel_name: nil,
          tiktok_url: nil
        )
      rescue JSON::ParserError => e
        Rails.logger.error "Ошибка парсинга JSON для сообщения ID: #{message.id} - #{e.message}\n#{e.backtrace.join("\n")}"
      rescue => e
        Rails.logger.error "Непредвиденная ошибка: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end
