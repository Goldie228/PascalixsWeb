class DiscordAvatar < ApplicationRecord
  belongs_to :discord_account
  has_one_attached :file

  validates :status, inclusion: { in: %w[pending approved rejected] }

  # Валидации для прикрепленного файла
  validates :file, content_type: {
    in: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
    message: I18n.t('activerecord.errors.messages.invalid_content_type')
  }, size: {
    less_than: 5.megabytes,
    message: I18n.t('activerecord.errors.messages.file_too_large')
  }, if: -> { file.attached? }

  # Метод для получения URL файла
  def avatar_file
    file
  end

  before_create -> { self.id ||= SecureRandom.uuid }
end
