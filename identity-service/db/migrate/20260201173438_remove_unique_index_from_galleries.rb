
class RemoveUniqueIndexFromGalleries < ActiveRecord::Migration[7.2]
  def change
    remove_index :galleries, name: :index_galleries_on_title
  end
end
