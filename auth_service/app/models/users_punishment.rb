class UsersPunishment < ApplicationRecord
  self.inheritance_column = "_type_disabled"

  belongs_to :user
  belongs_to :violator, class_name: "User", foreign_key: "bad_user_id"

  validates :user_id, :bad_user_id, :type, :issued_at, presence: true
  validates :type, inclusion: { in: %w[ban mute warning], message: "%{value} недопустимый тип наказания" }

  after_commit :update_redis_data, on: [ :create, :update, :destroy ]

  private

  def update_redis_data
    # Собираем активные наказания
    punishments = UsersPunishment.where(active: true, bad_user_id: bad_user_id)
    punishments_data = punishments.as_json(
      only: [ :id, :user_id, :type, :reason, :issued_at, :expires_at ]
    )

    # Обновляем ключ punishments:<user_id>
    REDIS_CLIENT.hset("punishments:#{bad_user_id}", "data", punishments_data.to_json)
    REDIS_CLIENT.expire("punishments:#{bad_user_id}", 86_400)

    # Удаляем устаревший кэш для punishment_history
    REDIS_CLIENT.del("punishment_history:#{MinecraftAccount.find_by(user_id: user_id)&.nickname}")

    # Посылаем событие в Kafka / Producer
    user = User.find_by(id: self.user_id)
    UserDataProducer.publish(user)

    Rails.logger.info("🔄 Redis обновлён для пользователя #{bad_user_id}: punishments + удалён punishment_history")
  rescue => e
    Rails.logger.error("❌ Ошибка обновления Redis для пользователя #{bad_user_id}: #{e.message}")
  end
end
