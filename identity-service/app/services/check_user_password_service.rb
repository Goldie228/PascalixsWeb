class CheckUserPasswordService
  class << self
    def call(user_id: nil, nickname: nil)
      account = if nickname.present?
                  MinecraftAccount.find_by(nickname: nickname.strip)
                elsif user_id.present?
                  MinecraftAccount.find_by(user_id: user_id)
                end

      unless account
        Rails.logger.warn "[PasswordSync] ❌ MinecraftAccount не найден (nickname=#{nickname.inspect}, user_id=#{user_id.inspect})"
        return
      end

      remote_hash = fetch_remote_password_hash(account)
      unless remote_hash.present?
        Rails.logger.warn "[PasswordSync] ❌ Нет хэша из API для #{account.nickname}"
        return
      end

      if secure_compare_hashes(account.password_hash, remote_hash)
        Rails.logger.info "[PasswordSync] ✅ Хэш пароля совпадает для #{account.nickname}"
      else
        account.update_attribute(:password_hash, remote_hash)
        Rails.logger.warn "[PasswordSync] 🔄 Обновлён хэш пароля для #{account.nickname}"
      end
    rescue => e
      Rails.logger.error "[PasswordSync] 💥 Ошибка: #{e.message}"
    end

    private

    def fetch_remote_password_hash(account)
      url = "#{ENV['GAME_SERVICE_URL']}/api/v1/players/#{account.nickname}/check_password"
      query = { nickname: account.nickname, password: account.password_hash }

      response = HTTParty.get(url, query: query, headers: {
        "Authorization" => "Bearer #{ENV['INTER_SERVICE_API_KEY']}",
        "Accept" => "application/json"
      })

      JSON.parse(response.body)["correct_hash"] rescue nil
    end

    def secure_compare_hashes(a, b)
      a.present? && b.present? && a == b
    end
  end
end
