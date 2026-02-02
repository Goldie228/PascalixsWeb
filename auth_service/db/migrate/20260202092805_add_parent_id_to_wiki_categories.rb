class AddParentIdToWikiCategories < ActiveRecord::Migration[7.2]
  def change
    # Добавляем колонку parent_id (так как у нас UUID, указываем лимит)
    add_reference :wiki_categories, :parent, type: :string, limit: 36, index: true

    # ВАЖНО: Мы НЕ добавляем foreign_key (foreign_key: { to_table: :wiki_categories }).
    # Почему? Потому что для самоссылающихся таблиц (Self-Referential) 
    # ограничения внешнего ключа в базе данных часто создают проблемы при создании первой записи (кто родитель у первого корня?).
    # Мы проверим целостность на уровне модели (Ruby).
  end
end
