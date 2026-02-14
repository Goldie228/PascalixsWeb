
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

  # ============================================
  # ИСПРАВЛЕНО: Методы для API сериализации
  # ============================================
  
  # Полная информация о странице со связями (для show, create, update)
  def page_details_with_associations
    as_json(
      include: {
        wiki_category: { only: [:id, :name, :slug] },
        wiki_downloads: { 
          only: [:id, :title, :description, :version, :slug, :position],
          methods: [:file_url, :filename, :file_size]
        }
      },
      methods: [:images_with_variants, :category_breadcrumb]
    )
  end
  
  # Список изображений с URL
  def images_with_variants
    images.map do |image|
      {
        id: image.id,
        signed_id: image.signed_id,
        filename: image.filename.to_s,
        content_type: image.content_type,
        byte_size: image.byte_size,
        url: Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
      }
    end
  end
  
  # Хлебные крошки категории
  def category_breadcrumb
    return nil unless wiki_category
    
    # Если у категории есть метод path, используем его
    if wiki_category.respond_to?(:path)
      wiki_category.path.map(&:name).join(' → ')
    else
      wiki_category.name
    end
  end

  private

  def set_slug
    self.slug = title.present? ? title.parameterize : nil
  end
end
