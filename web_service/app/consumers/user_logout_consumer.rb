
class UserLogoutConsumer < ApplicationConsumer
	def consume
		messages.each do |message|
			begin
				payload = JSON.parse(message.payload)
				Rails.logger.info("Processing logout event: #{payload['request_id']}")
				
				# Здесь можно добавить логику обработки событий выхода из системы
				# Например, обновление статистики сессий, логирование активности и т.д.
				
				# Пример логики:
				# 1. Логирование для аудита
				log_logout_activity(payload)
				
				# 2. Обновление последней активности пользователя
				update_user_last_activity(payload)
				
				Rails.logger.info("Successfully processed logout event: #{payload['request_id']}")
			rescue StandardError => e
				Rails.logger.error("Error processing logout event: #{e.message}")
				Rails.logger.error(e.backtrace.join("\n"))
			end
		end
	end
	
	private
	
	def log_logout_activity(payload)
		# Здесь можно добавить код для логирования события выхода из системы
		Rails.logger.info("User logged out: #{payload['token']} from IP #{payload['ip_address']} at #{Time.at(payload['timestamp'])}")
	end
	
	def update_user_last_activity(payload)
		# Здесь можно обновить информацию о последней активности пользователя
		# Например, через Redis или БД
		Rails.logger.info("Updating last activity for token: #{payload['token']}")
	end
end
