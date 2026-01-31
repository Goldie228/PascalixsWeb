class CreateGalleries < ActiveRecord::Migration[7.2]
  def change
    create_table :galleries do |t|
      t.string :title, null: false
      t.text :description

      t.timestamps
    end

    add_index :galleries, :title, unique: true
  end
end
