class ReportAttachment < ApplicationRecord
  belongs_to :user_report
  before_create :generate_uuid
  before_validation :normalize_content_type

  validates :filename, presence: true
  validates :content_type, presence: true
  validates :file_size, presence: true

  # Поддерживаемые типы файлов
  SUPPORTED_CONTENT_TYPES = [
    'image/jpeg',
    'image/png',
    'video/mp4',
    'application/mp4'
  ].freeze

  validates :content_type, inclusion: { in: SUPPORTED_CONTENT_TYPES }

  # Максимальный размер файла (2 ГБ)
  MAX_FILE_SIZE = 2.gigabytes
  validates :file_size, numericality: {
    less_than_or_equal_to: MAX_FILE_SIZE
  }

  # Возвращает URL для скачивания файла
  def download_url
    Rails.application.routes.url_helpers.rails_blob_path(
      user_report.attachments.find { |a| a.filename.to_s == filename },
      disposition: 'attachment'
    )
  end

  private

  def generate_uuid
    self.id = SecureRandom.uuid
  end

  def normalize_content_type
    self.content_type = 'video/mp4' if content_type == 'application/mp4'
  end
end
