class UserEventsProducer < ApplicationProducer
  # Событие при обновлении профиля пользователя
  def self.profile_updated(user_id, updated_fields)
    call(
      topic: :user_events,
      payload: {
        event_type: 'profile_updated',
        user_id: user_id,
        updated_fields: updated_fields,
        timestamp: Time.current
      }
    )
  end

  # Событие при активации двухфакторной аутентификации
  def self.two_factor_enabled(user_id)
    call(
      topic: :user_events,
      payload: {
        event_type: 'two_factor_enabled',
        user_id: user_id,
        timestamp: Time.current
      }
    )
  end

  # Событие при деактивации двухфакторной аутентификации
  def self.two_factor_disabled(user_id)
    call(
      topic: :user_events,
      payload: {
        event_type: 'two_factor_disabled',
        user_id: user_id,
        timestamp: Time.current
      }
    )
  end

  # Событие при подключении Discord аккаунта
  def self.discord_account_linked(user_id, discord_user_id)
    call(
      topic: :user_events,
      payload: {
        event_type: 'discord_account_linked',
        user_id: user_id,
        discord_user_id: discord_user_id,
        timestamp: Time.current
      }
    )
  end

  # Событие при подключении Minecraft аккаунта
  def self.minecraft_account_linked(user_id, minecraft_username)
    call(
      topic: :user_events,
      payload: {
        event_type: 'minecraft_account_linked',
        user_id: user_id,
        minecraft_username: minecraft_username,
        timestamp: Time.current
      }
    )
  end
end 