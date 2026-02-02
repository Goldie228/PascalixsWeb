
class WikiDownload < ApplicationRecord
  belongs_to :wiki_page
  
  # Файл для скачивания
  has_one_attached :file

  # Валидации
  validates :title, presence: true
  
  # Кастомная валидация на наличие файла
  validate :file_must_be_present

  scope :ordered, -> { order(position: :asc) }

  private

  def file_must_be_present
    # Если файл не прикреплен, добавляем ошибку
    errors.add(:file, 'должен быть загружен') unless file.attached?
  end
end
