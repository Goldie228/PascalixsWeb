module AuthServiceData
  extend ActiveSupport::Concern

  # Метод, который будет вызываться в контроллерах для загрузки данных пользователя
  def load_user_data
    return unless current_user

    # В реальной архитектуре здесь будет запрос к auth_service через API
    # или чтение данных из кэша, обновляемого через Kafka

    # Для локальной разработки используем заглушки
    if Rails.env.development?
      @user_data = {
        username: "TestUser",
        email: "test@example.com",
        discord_id: "123456789",
        minecraft_nickname: "TestPlayer",
        created_at: Time.current - 1.month,
        is_registered: true
      }
    else
      # В production здесь должен быть API-запрос к auth_service
      # с соответствующей аутентификацией
      @user_data = fetch_user_data_from_auth_service(current_user.id)
    end
  end

  private

  def fetch_user_data_from_auth_service(user_id)
    # Заглушка для метода, который будет делать реальный запрос к auth_service
    # В реальной имплементации здесь будет HTTP-запрос с аутентификацией
    # или другой механизм межсервисного взаимодействия
    {}
  end
end 