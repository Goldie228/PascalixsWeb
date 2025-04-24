
class UserRegistrationConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = JSON.parse(message.payload)
      Rails.logger.info("Received registration event: #{payload}")
      
      # Обработка события регистрации пользователя
      # Например, создание пользователя в локальной базе данных, если его еще нет
      user_id = payload['user_id']
      email = payload['email']
      
      unless User.exists?(id: user_id)
        # Создаем локальную запись пользователя
        user = User.new(
          id: user_id,
          email: email,
          username: payload['username'],
          created_at: Time.parse(payload['created_at']),
          is_registered: true
        )
        
        if user.save
          Rails.logger.info("User #{email} registered and saved to local database")
        else
          Rails.logger.error("Failed to save user #{email} to local database: #{user.errors.full_messages.join(', ')}")
        end
      else
        Rails.logger.info("User #{email} already exists in local database")
      end
    end
  end
end
