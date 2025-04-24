module V1
  class UserLogoutConsumer < Karafka::BaseConsumer
    def consume
      messages.each do |message|
        begin
          data = JSON.parse(message.payload)
          Rails.logger.info("Received logout event: #{data}")
          
          # Извлекаем токен из данных
          token = data['token']
          ip_address = data['ip_address']
          timestamp = data['timestamp']
          
          if token.present?
            session = Session.find_by(token: token)
            
            if session
              user = session.user
              Rails.logger.info("User #{user.id} logged out at #{Time.at(timestamp)} from IP #{ip_address}")
              
              # Обновление информации о последнем выходе
              user.update(last_logout_at: Time.at(timestamp))
              
              # Добавить запись в журнал аудита
              AuditLog.create(
                user_id: user.id,
                action: 'logout',
                ip_address: ip_address,
                created_at: Time.at(timestamp)
              )
              
              Rails.logger.info("Successfully processed logout event for user #{user.id}")
            else
              Rails.logger.warn("No session found for token: #{token}")
            end
          else
            Rails.logger.warn("Received logout event without token")
          end
        rescue StandardError => e
          Rails.logger.error("Error processing logout event: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        end
      end
    end
  end
end 