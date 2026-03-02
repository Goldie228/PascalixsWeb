class AddPositionToWikiCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :wiki_categories, :position, :integer, default: 0, null: false
    
    # Устанавливаем позиции для существующих категорий
    reversible do |dir|
      dir.up do
        execute <<-SQL
          WITH ordered_categories AS (
            SELECT id, ROW_NUMBER() OVER (ORDER BY name) - 1 AS new_position
            FROM wiki_categories
          )
          UPDATE wiki_categories
          SET position = ordered_categories.new_position
          FROM ordered_categories
          WHERE wiki_categories.id = ordered_categories.id
        SQL
      end
    end
  end
end