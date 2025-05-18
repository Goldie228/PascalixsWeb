class RemoveDescriptionFromDiscordAccounts < ActiveRecord::Migration[7.2]
  def change
    remove_column :discord_accounts, :description, :string
  end
end
