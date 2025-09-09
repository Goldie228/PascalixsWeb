class Purchase < ApplicationRecord
  # --- Ассоциации ---
  belongs_to :purchaser, class_name: "User", foreign_key: :purchaser_user_id
  belongs_to :target,    class_name: "User", foreign_key: :target_user_id, optional: true
  belongs_to :punishment, class_name: "UsersPunishment", optional: true

  # Один прикреплённый файл
  has_one_attached :receipt

  # --- Enum'ы ---
  enum :purchase_type,
       {
         pass_purchase: "pass_purchase",
         pass_gift:     "pass_gift",
         sponsor:       "sponsor",
         unban:         "unban",
         unmute:        "unmute"
       },
       prefix: :type

  enum :status,
       {
         pending:  "pending",
         approved: "approved",
         rejected: "rejected"
       },
       prefix: :status

  # --- Валидации ---
  validates :purchase_type, presence: true, inclusion: { in: purchase_types.keys }
  validates :status,        presence: true, inclusion: { in: statuses.keys }
  validates :amount,        numericality: { greater_than_or_equal_to: 0 }
  validates :currency,      presence: true, length: { maximum: 8 }
  validates :purchaser_user_id, presence: true

  validate :target_required_for_gift_and_actions
  validate :punishment_presence_for_unban_unmute_if_provided
  validate :receipt_image_only

  before_validation :assign_default_target_for_selfish_types

  scope :recent, -> { order(created_at: :desc) }

  private

  # --- Заполнение target, если не указан ---
  def assign_default_target_for_selfish_types
    if target_user_id.blank? && (type_pass_purchase? || type_sponsor?)
      self.target_user_id = purchaser_user_id
    end
  end

  # --- Целевой пользователь обязателен для некоторых типов ---
  def target_required_for_gift_and_actions
    if target_user_id.blank? && type_pass_gift?
      errors.add(:target_user_id, "обязателен для этого типа покупки")
    end
  end

  # --- Проверка punishment для unban/unmute ---
  def punishment_presence_for_unban_unmute_if_provided
    return unless (type_unban? || type_unmute?)

    if punishment && !punishment.active
      errors.add(:punishment_id, "указывает на неактивное наказание")
    end
  end

  # --- Проверка файла чека ---
  def receipt_image_only
    return unless receipt.attached?

    unless receipt.blob.content_type&.start_with?("image/")
      errors.add(:receipt, "должно быть изображением (PNG/JPG)")
    end

    if receipt.blob.byte_size > 5.megabytes
      errors.add(:receipt, "слишком большой файл (макс 5 МБ)")
    end
  end
end
