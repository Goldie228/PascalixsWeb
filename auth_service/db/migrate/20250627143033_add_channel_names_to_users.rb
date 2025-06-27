class AddChannelNamesToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :youtube_channel_name, :string
    add_column :users, :twitch_channel_name, :string
    add_column :users, :tiktok_channel_name, :string
  end
end
