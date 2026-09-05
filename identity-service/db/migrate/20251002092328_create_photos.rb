class CreatePhotos < ActiveRecord::Migration[7.2]
  def change
    create_table :photos do |t|
      t.references :gallery, null: false, foreign_key: true
      t.string :title

      t.timestamps
    end

    add_index :photos, :title
  end
end
