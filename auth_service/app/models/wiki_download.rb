
class WikiDownload < ApplicationRecord
  belongs_to :wiki_page
  has_one_attached :file

  validates :title, presence: true

  validates :file, attached: true

  scope :ordered, -> { order(position: :asc) }

  # Вспомогательный метод для сериализации JSON
  def file_url
    Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true) if file.attached?
  end
end
