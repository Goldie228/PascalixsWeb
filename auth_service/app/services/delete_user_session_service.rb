class DeleteUserSessionService
  class << self
    def call(user_id:, nickname:)
      total_deleted = 0

      REDIS_CLIENT.scan_each(match: "session:2::*") do |key|
        begin
          raw = REDIS_CLIENT.get(key)
          next unless raw

          session_data = Marshal.load(raw) rescue nil
          next unless session_data.is_a?(Hash)

          has_user_id    = session_data["user_id"] == user_id
          has_nickname   = session_data["nickname"] == nickname

          if has_user_id || has_nickname
            REDIS_CLIENT.del(key)
            Rails.logger.info "[SessionCleaner] 🧹 Удалён session-ключ #{key}"
            total_deleted += 1
          end
        rescue => e
          Rails.logger.warn "[SessionCleaner] ❌ Ошибка при проверке session-ключа #{key}: #{e.message}"
        end
      end

      [  "*#{user_id}*", "*#{nickname}*" ].each do |pattern|
        REDIS_CLIENT.scan_each(match: pattern) do |key|
          next if key.start_with?("session:2::")

          begin
            REDIS_CLIENT.del(key)
            Rails.logger.info "[SessionCleaner] 🧹 Удалён ключ #{key}"
            total_deleted += 1
          rescue => e
            Rails.logger.warn "[SessionCleaner] ❌ Ошибка при удалении #{key}: #{e.message}"
          end
        end
      end

      Rails.logger.info "[SessionCleaner] ✅ Итого удалено: #{total_deleted} ключей для user_id=#{user_id}, nickname=#{nickname}"
      total_deleted
    end
  end
end
