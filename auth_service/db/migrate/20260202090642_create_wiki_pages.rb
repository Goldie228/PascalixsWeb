class CreateWikiPages < ActiveRecord::Migration[7.2]
  def change
    create_table :wiki_pages, id: :string, limit: 36 do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :content, null: false
      
      t.string :wiki_category_id, limit: 36
      t.boolean :published, default: false, null: false
      
      # Добавили поле для ручной сортировки
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :wiki_pages, :slug, unique: true
    # Составной индекс для быстрого выбора страниц внутри конкретной категории
    add_index :wiki_pages, [:wiki_category_id, :published]
    
    add_foreign_key :wiki_pages, :wiki_categories, on_delete: :nullify
  end
end
