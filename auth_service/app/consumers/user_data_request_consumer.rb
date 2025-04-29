# app/consumers/user_data_request_consumer.rb
class UserDataRequestConsumer < ApplicationConsumer
  def consume
    Rails.logger.info "Получено #{messages.count} сообщений в UserDataRequestConsumer"
    
    messages.each do |message|
      payload = message.payload
      user_id = payload['user_id']
      Rails.logger.info "Обработка запроса данных для пользователя с id: #{user_id}"
      
      # Получаем данные пользователя из базы данных
      user = User.find_by(id: user_id)
      
      if user.present?
        UserDataProducer.publish(user)

        Rails.logger.info "Данные пользователя отправлены через UserDataProducer"
      else
        Rails.logger.warn "Пользователь с id #{user_id} не найден"
      end
    end
  rescue => e
    Rails.logger.error "Ошибка в UserDataRequestConsumer: #{e.message}"
  end
end
