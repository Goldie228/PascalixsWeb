class DiscordAvatar < ApplicationRecord
  belongs_to :discord_account

  # Генерируем ID перед созданием, если он не установлен
  before_validation :generate_id, on: :create

  has_one_attached :file do |attachable|
    attachable.variant :thumb, resize_to_limit: [512, 512]
  end

  validates :status, inclusion: { in: %w[pending approved rejected] }

  validates :file, content_type: {
    in: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
    message: I18n.t('activerecord.errors.messages.invalid_content_type')
  }, size: {
    less_than: 10.megabytes,
    message: I18n.t('activerecord.errors.messages.file_too_large')
  }, if: -> { file.attached? }

  after_commit :process_gif_async, on: [:create], if: -> { file.attached? && file.content_type == 'image/gif' }

  def process_gif_async
    ProcessGifJob.set(wait: 1.second).perform_later(id)
  end

  def processed?
    file.attached? && status != 'pending'
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end
end
