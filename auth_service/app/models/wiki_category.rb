class WikiCategory < ApplicationRecord
  # --- Автогенерация UUID ---
  before_create :generate_uuid
  
  # --- Связи ---
  
  # Самоссылающаяся связь. Категория принадлежит родителю
  belongs_to :parent, class_name: 'WikiCategory', optional: true
  
  # Категория имеет много детей
  has_many :children, class_name: 'WikiCategory', foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent
  
  has_many :wiki_pages, dependent: :nullify

  # --- Валидации ---
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Защита от циклических ссылок
  validate :parent_cannot_be_self_or_descendant

  # --- Scopes ---
  scope :roots, -> { where(parent_id: nil) }
  scope :alphabetically, -> { order(name: :asc) }
  scope :ordered, -> { order(position: :asc) }

  # --- Методы навигации ---

  def root?
    parent_id.nil?
  end

  # Возвращает полный путь от корня до текущей категории
  def path
    ancestors = []
    category = self
    
    while category.parent
      category = category.parent
      ancestors << category
    end
    
    ancestors.reverse + [self]
  end
  
  # ИСПРАВЛЕНО: Хлебные крошки как строка (для API)
  def breadcrumb_path
    path.map(&:name).join(' → ')
  end

  # Возвращает массив всех потомков
  def descendants
    children.flat_map { |child| [child] + child.descendants }
  end
  
  # Проверка: является ли другая категория потомком текущей
  def descendant_of?(other)
    return false unless other
    descendants.include?(other)
  end

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end

  def parent_cannot_be_self_or_descendant
    if parent == self
      errors.add(:parent, "не может быть самой собой")
    elsif parent && descendants.include?(parent)
      errors.add(:parent, "не может быть потомком (обнаружен цикл)")
    end
  end
end
