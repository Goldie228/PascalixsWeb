
class WikiPage < ApplicationRecord
  belongs_to :wiki_category, optional: true
  
  # Файлы (моды) будут доставаться уже отсортированными благодаря -> { ordered }
  has_many :wiki_downloads, -> { ordered }, dependent: :destroy, inverse_of: :wiki_page
  
  # Картинки для Markdown текста
  has_many_attached :images

  # Валидации
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :content, presence: true

  # Scopes для чистоты контроллеров
  scope :published, -> { where(published: true) }
  scope :ordered,   -> { order(position: :asc) }
  
  # Хелпер для поиска опубликованной страницы по слагу (удобно в контроллерах)
  def self.find_published(slug)
    published.find_by(slug: slug)
  end

  # Автоматизация: если слаг не указан, генерируем из заголовка (транслитерация)
  before_validation :set_slug, if: -> { slug.blank? }

  private

  def set_slug
    self.slug = title.present? ? title.parameterize : nil
  end
end
