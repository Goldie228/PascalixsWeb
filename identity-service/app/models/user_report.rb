class UserReport < ApplicationRecord
  # Связи
  belongs_to :reporter, class_name: 'User'
  belongs_to :reported_user, class_name: 'User'
  before_create :generate_uuid
  has_many :report_attachments, dependent: :destroy

  # Active Storage для прикрепления файлов
  has_many_attached :attachments

  validates :title, presence: true
  validates :description, presence: true

  # Валидация
  validates :title, presence: true, length: { maximum: 80 }
  validates :description, presence: true, length: { maximum: 5000 }

  # Проверка, что пользователь не жалуется на себя
  validate :reporter_cannot_be_reported_user

  # Проверка количества файлов
  validate :validate_attachments_count

  # Проверка типов файлов
  validate :validate_attachments_type

  # Проверка размера файлов
  validate :validate_attachments_size

  # Статус жалобы (active/inactive)
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }

  private

  def reporter_cannot_be_reported_user
    if reporter_id == reported_user_id
      errors.add(:base, "Вы не можете пожаловаться на самого себя")
    end
  end

  def validate_attachments_count
    if attachments.size > 12
      errors.add(:attachments, "можно прикрепить не более 12 файлов")
    end
  end

  def validate_attachments_type
    attachments.each do |attachment|
      unless attachment.content_type.in?(%w[image/jpeg image/png video/mp4])
        errors.add(:attachments, "#{attachment.filename} имеет неподдерживаемый формат")
      end
    end
  end

  def validate_attachments_size
    attachments.each do |attachment|
      if attachment.byte_size > 2.gigabytes
        errors.add(:attachments, "#{attachment.filename} слишком большой (максимум 2 ГБ)")
      end
    end
  end

  def generate_uuid
    self.id = SecureRandom.uuid
  end
end
