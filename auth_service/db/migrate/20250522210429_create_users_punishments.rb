class CreateUsersPunishments < ActiveRecord::Migration[7.2]
  def change
    create_table :users_punishments do |t|
      t.string   :user_id,          limit: 36,     null: false
      t.string   :bad_user_id,      limit: 36,     null: false
      t.string   :type,                            null: false
      t.text     :reason
      t.decimal  :withdrawal_price, precision: 10, scale: 2
      t.datetime :issued_at,                       null: false
      t.integer  :duration
      t.datetime :expires_at
      t.boolean  :active,           default: true

      t.timestamps
    end

    add_foreign_key :users_punishments, :users, column: :user_id,     primary_key: "id"
    add_foreign_key :users_punishments, :users, column: :bad_user_id, primary_key: "id"
  end
end
