class CreateWikiDownloads < ActiveRecord::Migration[7.2]
  def change
    create_table :wiki_downloads, id: :string, limit: 36 do |t|
      t.string :wiki_page_id, limit: 36, null: false
      t.string :title, null: false
      t.text :description
      
      # Добавили поле для ручной сортировки
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :wiki_downloads, :wiki_page_id
    
    add_foreign_key :wiki_downloads, :wiki_pages, on_delete: :cascade
  end
end
