class UsersPunishment < ApplicationRecord
  self.inheritance_column = "_type_disabled"

  belongs_to :user
  belongs_to :bad_user, class_name: "User", foreign_key: :bad_user_id
  belongs_to :punishment_reason

  VALID_TYPES = %w[ban mute].freeze

  validates :user_id, :bad_user_id, :type, :issued_at, :punishment_reason, presence: true
  validates :type, inclusion: { in: VALID_TYPES, message: "%{value} недопустимый тип наказания" }

  # Тип наказания в записи должен совпадать с типом в справочнике
  validate :punishment_type_matches_reason

  # Удобные прокси-методы для сериализации/доступа
  delegate :description, to: :punishment_reason, prefix: :reason
  delegate :rule_number, :price, to: :punishment_reason, prefix: true

  after_commit :update_redis_data, on: %i[create update destroy]

  private

  def punishment_type_matches_reason
    return if punishment_reason.nil?
    if punishment_reason.punishment_type != type
      errors.add(:punishment_reason, "тип причины (#{punishment_reason.punishment_type}) не совпадает с типом наказания (#{type})")
    end
  end

  def update_redis_data
    # Собираем активные наказания
    punishments = UsersPunishment.where(active: true, bad_user_id: bad_user_id)

    # В Redis отправляем плоские данные + атрибуты из справочника
    punishments_data = punishments.as_json(
      only: %i[id user_id type issued_at expires_at],
      methods: %i[reason_description punishment_reason_rule_number punishment_reason_price]
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
