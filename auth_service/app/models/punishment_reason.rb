class PunishmentReason < ApplicationRecord
  has_many :users_punishments, dependent: :restrict_with_exception

  VALID_TYPES = %w[ban mute].freeze

  validates :punishment_type, presence: true, inclusion: { in: VALID_TYPES }
  validates :description, :rule_number, :price, presence: true
  validates :rule_number, numericality: { only_integer: true, greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  validates :rule_number, uniqueness: { scope: :punishment_type, message: "должен быть уникален в рамках типа наказания" }
end
