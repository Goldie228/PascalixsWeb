class UserLoginConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      data = JSON.parse(message.payload)
      correlation_id = data["correlation_id"]

      begin
        minecraft_account = MinecraftAccount.find_by(nickname: data["nickname"])

        # Если аккаунт не найден — сразу отвечаем ошибкой
        unless minecraft_account
          send_failure(correlation_id)
          next  # Выходим из данной итерации
        end

        # Проверяем пароль
        if minecraft_account.authenticate(data["password"])
          send_success(correlation_id, minecraft_account.user.id)
          UserDataProducer.publish(minecraft_account.user)
        else
          send_failure(correlation_id)
        end

      rescue => e
        Rails.logger.error "Login processing failed: #{e.message}"
        send_failure(correlation_id)
      end
    end
  end

  private

  def send_success(correlation_id, user_id)
    payload = { status: "auth", user_id: user_id }.to_json
    Rails.logger.info "Login success: correlation_id=#{correlation_id}, user_id=#{user_id}"
    REDIS_CLIENT.publish("auth_responses:#{correlation_id}", payload)
  end

  def send_failure(correlation_id)
    payload = { status: "not auth", user_id: nil }.to_json
    Rails.logger.warn "Login failure: correlation_id=#{correlation_id}, user_id=nil"
    REDIS_CLIENT.publish("auth_responses:#{correlation_id}", payload)
  end
end
