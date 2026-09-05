
class DeleteUserSessionService
  class << self
    def call(user_id:, nickname:)
      total_deleted = 0
      uid_str  = user_id.to_s
      nick_str = nickname.to_s

      # Первичный проход по сессиям, которые выглядят как session:2::*
      REDIS_CLIENT.scan_each(match: "session:2::*") do |key|
        begin
          raw = REDIS_CLIENT.get(key)
          next unless raw && raw.length > 0

          matched = false

          # 1) Попытка безопасно распарсить JSON (если сессии уже в JSON)
          begin
            parsed = JSON.parse(raw) rescue nil
            if parsed.is_a?(Hash)
              # Сравниваем как строки
              has_user_id  = parsed["user_id"].to_s == uid_str
              has_nickname = parsed["nickname"].to_s == nick_str
              matched = has_user_id || has_nickname
            end
          rescue JSON::ParserError
            # не JSON — просто пропускаем, пойдем к безопасной проверке ниже
          end

          # 2) Если не JSON или JSON не дал совпадения — выполняем безопасную проверку "сырых" данных.
          #    Здесь мы НЕ десериализуем, а ищем в бинарном/строчном представлении точные вхождения ID/никнейма.
          #    Это может давать false-positive, но безопаснее, чем Marshal.load.
          if !matched
            # Приводим raw к строке безопасно; используем ASCII-8BIT -> UTF-8 преобразование с замещением
            raw_str = raw.to_s.force_encoding('ASCII-8BIT')
            # Проверяем наличие точных подстрок. Для снижения ложных срабатываний можно применять
            # границы (например, искать `"user_id"` рядом с uid), но это зависит от формата.
            if raw_str.include?(uid_str) || (nick_str.present? && raw_str.include?(nick_str))
              matched = true
            end
          end

          if matched
            REDIS_CLIENT.del(key)
            Rails.logger.info "[SessionCleaner] 🧹 Удалён session-ключ #{key}"
            total_deleted += 1
          end
        rescue => e
          Rails.logger.warn "[SessionCleaner] ❌ Ошибка при проверке session-ключа #{key}: #{e.class}: #{e.message}"
          # не восстанавливаем неизвестные исключения — продолжаем
        end
      end

      # Второй проход: ключи по шаблону (как у вас было). Будьте осторожны с такими шаблонами.
      [ "*#{uid_str}*", "*#{nick_str}*" ].each do |pattern|
        next if pattern.blank?
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
