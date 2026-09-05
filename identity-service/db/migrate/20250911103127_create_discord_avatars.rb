class CreateDiscordAvatars < ActiveRecord::Migration[7.2]
  def change
    create_table :discord_avatars, id: { type: :string, limit: 36 } do |t|
      t.string :discord_account_id, null: false, limit: 36
      t.string :status, null: false, default: 'pending'
      t.string :original_url
      t.timestamps
    end

    add_foreign_key :discord_avatars, :discord_accounts
    add_index :discord_avatars, :discord_account_id
    add_index :discord_avatars, :status
    add_index :discord_avatars, :created_at
  end
end
