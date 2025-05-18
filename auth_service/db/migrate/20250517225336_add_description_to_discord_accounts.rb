class AddDescriptionToDiscordAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :discord_accounts, :description, :string
  end
end
