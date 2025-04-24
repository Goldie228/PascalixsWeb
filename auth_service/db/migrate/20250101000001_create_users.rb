class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.string :username
      t.string :first_name
      t.string :last_name
      t.timestamps
    end
  end
end 