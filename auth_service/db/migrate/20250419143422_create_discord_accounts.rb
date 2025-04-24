class CreateDiscordAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table "discord_accounts", id: { type: :string, limit: 36, primary_key: true } do |t|
      t.string "user_id", limit: 36, null: false
      t.string "discord_id", null: false
      t.string "username", null: false
      t.string "discriminator"
      t.string "email", null: false
      t.string "avatar", null: false

      t.index ["discord_id"], name: "index_discord_accounts_on_discord_id", unique: true
      t.index ["user_id"], name: "index_discord_accounts_on_user_id", unique: true
      t.index ["username"], name: "index_discord_accounts_on_username"

      t.foreign_key "users", column: "user_id"
    end
  end
end
