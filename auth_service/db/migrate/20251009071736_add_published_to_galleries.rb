class AddPublishedToGalleries < ActiveRecord::Migration[7.2]
  def change
    add_column :galleries, :published, :boolean, default: false

    add_index :galleries, :published
  end
end
