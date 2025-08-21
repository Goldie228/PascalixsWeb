class RenameTypeToProductTypeInProducts < ActiveRecord::Migration[7.2]
  def change
    rename_column :products, :type, :product_type
  end
end
