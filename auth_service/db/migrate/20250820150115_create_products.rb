class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.string :type
      t.decimal :price, precision: 10, scale: 2
      t.timestamps
    end
    
    add_index :products, :type, unique: true
  end
end
