class MinecraftRegistrationConsumer < ApplicationConsumer
  def consume
    Rails.logger.info "MinecraftRegistrationConsumer started consuming messages"

    messages.each do |message|
      begin
        # 1. Получаем сырые данные сообщения
        raw_payload = message.payload
        Rails.logger.info "Received raw message: #{raw_payload}"

        # 2. Парсим JSON сообщение
        payload = JSON.parse(raw_payload["payload"].to_json)
        Rails.logger.info "Parsed payload: #{payload.inspect}"

        # 3. Извлекаем данные из сообщения
        correlation_id = payload["correlation_id"]
        user_id = payload["user_id"]
        locale = payload["locale"]
        nickname = payload["nickname"]
        password = payload["password"]
        password_confirmation = payload["password_confirmation"]

        # Устанавливаем локаль для сообщений об ошибках
        I18n.locale = locale

        # 4. Поиск пользователя по user_id
        user = User.find(user_id)
        Rails.logger.info "User found: #{user.id}"

        # 5. Создание аккаунта Minecraft для пользователя
        account = user.build_minecraft_account(
          nickname: nickname,
          password: password,
          password_confirmation: password_confirmation
        )

        # 6. Проверка, успешно ли сохранен аккаунт
        if account.save
          Rails.logger.info "Account created: #{account.inspect}"

          # 7. Отправка успешного ответа
          send_response(
            correlation_id: correlation_id,
            status: :success
          )

          UserDataProducer.publish(user)
        else
          # 8. Логируем ошибки валидации
          Rails.logger.error "Validation errors: #{account.errors.full_messages.join(", ")}"

          formatted_errors = account.errors.messages.each_with_object({}) do |(field, messages), hash|
            hash[field] = messages.first
          end

          # 10. Отправка ошибок в ответе
          send_response(
            correlation_id: correlation_id,
            status: :error,
            errors: formatted_errors
          )
        end

      rescue ActiveRecord::RecordNotFound => e
        # 11. Обработка случая, когда пользователь не найден
        Rails.logger.error "User not found: #{e.message}"
        send_response(
          correlation_id: correlation_id,
          status: :error,
          errors: { user: [I18n.t("errors.user_not_found")] } # Отправляем ошибку о том, что пользователь не найден
        )

      rescue JSON::ParserError => e
        # 12. Обработка ошибок парсинга JSON
        Rails.logger.error "Invalid JSON format: #{e.message}"

      rescue => e
        # 13. Обработка неожиданных ошибок
        Rails.logger.error "Unexpected error: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end

  private

  def send_response(correlation_id:, status:, payload: nil, errors: {})
    response = {
      correlation_id: correlation_id,
      status: status,
      timestamp: Time.current.iso8601
    }

    response.merge!(payload: payload) if payload
    response.merge!(errors: errors) if errors.any?

    # Формируем ключ для Redis и сохраняем сообщение с TTL 1 час (3600 секунд)
    redis_key = "registration_responses:#{correlation_id}"
    REDIS_CLIENT.set(redis_key, response.to_json, ex: 3600)
    Rails.logger.info "Response saved in Redis for correlation ID: #{correlation_id} with TTL of 1 hour"
  end
end
