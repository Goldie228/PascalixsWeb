class UserEventsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      with_deduplication("user_event:#{message.offset}") do
        process_message(message)
      end
    end
  end

  private

  def process_message(message)
    payload = JSON.parse(message.payload)
    event_type = payload['event_type']
    
    log_event("user_events_consumer", payload)
    
    case event_type
    when 'profile_updated'
      handle_profile_updated(payload)
    when 'two_factor_enabled'
      handle_two_factor_enabled(payload)
    when 'two_factor_disabled'
      handle_two_factor_disabled(payload)
    when 'discord_account_linked'
      handle_discord_account_linked(payload)
    when 'minecraft_account_linked'
      handle_minecraft_account_linked(payload)
    else
      Rails.logger.info "Неизвестное пользовательское событие: #{event_type}"
    end
  end

  def handle_profile_updated(payload)
    Rails.logger.info "Обновлен профиль пользователя: #{payload['user_id']}, поля: #{payload['updated_fields']}"
    # Здесь можно обновить кэш профиля пользователя
  end

  def handle_two_factor_enabled(payload)
    Rails.logger.info "Включена двухфакторная аутентификация: #{payload['user_id']}"
    # Здесь можно обновить настройки пользователя в UI
  end

  def handle_two_factor_disabled(payload)
    Rails.logger.info "Отключена двухфакторная аутентификация: #{payload['user_id']}"
    # Здесь можно обновить настройки пользователя в UI
  end

  def handle_discord_account_linked(payload)
    Rails.logger.info "Привязан Discord аккаунт: пользователь #{payload['user_id']}, Discord ID: #{payload['discord_user_id']}"
    # Здесь можно обновить информацию о пользователе в UI
  end

  def handle_minecraft_account_linked(payload)
    Rails.logger.info "Привязан Minecraft аккаунт: пользователь #{payload['user_id']}, ник: #{payload['minecraft_username']}"
    # Здесь можно обновить информацию о пользователе в UI
  end
  
  def log_event(consumer_name, payload)
    Rails.logger.debug "[#{consumer_name}] Получено событие: #{payload['event_type']} для пользователя #{payload['user_id']}"
  end
end 