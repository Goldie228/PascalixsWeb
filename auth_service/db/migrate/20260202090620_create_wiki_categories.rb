class CreateWikiCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :wiki_categories, id: :string, limit: 36 do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description

      t.timestamps
    end

    add_index :wiki_categories, :slug, unique: true
  end
end
