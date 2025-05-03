class UserLoginConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      data = JSON.parse(message.payload)
      correlation_id = data['correlation_id']

      begin
        minecraft_account = MinecraftAccount.find_by(nickname: data['nickname'])

        # Если аккаунт не найден - сразу отвечаем ошибкой
        unless minecraft_account
          send_failure(correlation_id)
          next  # Важно прервать выполнение итерации
        end

        # Проверяем пароль
        if minecraft_account.authenticate(data['password'])
          send_success(correlation_id, minecraft_account.user_id)
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
    Karafka.producer.produce_async(
      topic: 'user_login_responses',
      payload: {
        status: 'auth',
        correlation_id: correlation_id,
        user_id: user_id
      }.to_json
    )
  end

  def send_failure(correlation_id)
    Karafka.producer.produce_async(
      topic: 'user_login_responses',
      payload: {
        status: 'not auth',
        correlation_id: correlation_id,
        user_id: nil
      }.to_json
    )
  end
end