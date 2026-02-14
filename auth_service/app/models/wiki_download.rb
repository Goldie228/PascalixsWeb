class WikiDownload < ApplicationRecord
  belongs_to :wiki_page
  has_one_attached :file

  validates :title, presence: true
  validates :file, attached: true

  scope :ordered, -> { order(position: :asc) }

  # URL файла
  def file_url
    Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true) if file.attached?
  end
  
  # ИСПРАВЛЕНО: Имя файла
  def filename
    file.attached? ? file.filename.to_s : nil
  end
  
  # ИСПРАВЛЕНО: Размер файла
  def file_size
    file.attached? ? file.byte_size : nil
  end
end
