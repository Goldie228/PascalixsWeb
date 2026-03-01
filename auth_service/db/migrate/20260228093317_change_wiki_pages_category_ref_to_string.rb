class ChangeWikiPagesCategoryRefToString < ActiveRecord::Migration[7.2]
  def change
    # Удаляем foreign key constraint
    remove_foreign_key :wiki_pages, :wiki_categories
    
    # Удаляем старую integer колонку
    remove_column :wiki_pages, :wiki_category_id
    
    # Добавляем новую string колонку (UUID, как у wiki_categories.id)
    add_column :wiki_pages, :wiki_category_id, :string, limit: 36
    
    # Добавляем индекс
    add_index :wiki_pages, :wiki_category_id
    
    # Добавляем foreign key обратно
    add_foreign_key :wiki_pages, :wiki_categories, on_delete: :nullify
  end
end