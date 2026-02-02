
class WikiCategory < ApplicationRecord
  # --- Связи ---
  
  # Самоссылающаяся связь. Категория принадлежит родителю
  belongs_to :parent, class_name: 'WikiCategory', optional: true
  
  # Категория имеет много детей
  # Используем inverse_of, чтобы Rails лучше кешировал связи в памяти
  has_many :children, class_name: 'WikiCategory', foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent
  
  has_many :wiki_pages, dependent: :nullify

  # --- Валидации ---

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Защита от циклических ссылок (A -> B -> A)
  validate :parent_cannot_be_self_or_descendant

  # --- Scopes ---

  scope :roots, -> { where(parent_id: nil) }
  scope :alphabetically, -> { order(name: :asc) }

  # --- Методы навигации и состояния ---

  # Является ли категория корневой (не имеет родителя)?
  def root?
    parent_id.nil?
  end

  # Возвращает полный путь от корня до текущей категории (массив объектов).
  # Полезно для вывода "хлебных крошек" (Breadcrumbs).
  # 
  # Пример: [Моды, Клиентские моды, Моды на оптимизацию]
  def path
    ancestors = []
    category = self
    
    # Поднимаемся вверх по дереву
    while category.parent
      category = category.parent
      ancestors << category
    end
    
    # Разворачиваем массив, чтобы порядок был: Корень -> ... -> Текущая
    ancestors.reverse + [self]
  end

  # Возвращает массив всех потомков (включая вложенных).
  # 
  # ВНИМАНИЕ (Performance): Этот метод рекурсивно вызывает children.
  # Он генерирует N+1 запросов, если дерево глубокое.
  # Если категорий станет больше 100-200, лучше заменить на гем 'ancestry' 
  # или использовать запрос с Recursive CTE.
  def descendants
    children.flat_map { |child| [child] + child.descendants }
  end

  private

  def parent_cannot_be_self_or_descendant
    # Нельзя сделать самого себя родителем
    if parent == self
      errors.add(:parent, "не может быть самой собой")
    # Нельзя сделать потомка родителем (проверка через descendants)
    elsif parent && descendants.include?(parent)
      errors.add(:parent, "не может быть потомком (обнаружен цикл)")
    end
  end
end
