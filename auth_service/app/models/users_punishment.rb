class UsersPunishment < ApplicationRecord
  self.inheritance_column = "_type_disabled"

  belongs_to :user
  belongs_to :violator, class_name: "User", foreign_key: "bad_user_id"

  validates :user_id, :bad_user_id, :type, :issued_at, presence: true
  validates :type, inclusion: { in: %w[ban mute warning], message: "%{value} недопустимый тип наказания" }

  after_commit :update_redis_data, on: [ :create, :update, :destroy ]

  private

  def update_redis_data
    punishments = UsersPunishment.where(active: true, bad_user_id: bad_user_id)
    punishments_data = punishments.as_json(only: [ :id, :user_id, :type, :reason, :issued_at, :expires_at ])

    REDIS_CLIENT.hset("punishments:#{bad_user_id}", "data", punishments_data.to_json)
    REDIS_CLIENT.expire("punishments:#{bad_user_id}", 86_400)

    Rails.logger.info("Обновлены данные наказаний для пользователя #{bad_user_id} в Redis")
  rescue => e
    Rails.logger.error("Ошибка обновления данных в Redis для пользователя #{bad_user_id}: #{e.message}")
  end
end
