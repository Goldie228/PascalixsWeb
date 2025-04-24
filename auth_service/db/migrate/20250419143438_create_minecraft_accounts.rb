class CreateMinecraftAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table "minecraft_accounts", id: { type: :string, limit: 36, primary_key: true } do |t|
      t.string "user_id", limit: 36, null: false
      t.string "nickname", null: false
      t.string "password_hash", null: false

      t.index ["nickname"], name: "index_minecraft_accounts_on_nickname", unique: true
      t.index ["user_id"], name: "index_minecraft_accounts_on_user_id", unique: true

      t.foreign_key "users", column: "user_id"
    end
  end
end
