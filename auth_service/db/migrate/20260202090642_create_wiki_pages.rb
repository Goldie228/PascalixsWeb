class CreateWikiPages < ActiveRecord::Migration[7.2]
  def change
    create_table :wiki_pages do |t| # дефолтный integer id
      t.string :title, null: false
      t.string :slug, null: false
      t.text :content, null: false
      
      t.references :wiki_category, null: true, foreign_key: { on_delete: :nullify }
      t.boolean :published, default: false, null: false
      
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :wiki_pages, :slug, unique: true
    add_index :wiki_pages, [:wiki_category_id, :published]
  end
end
