class AddUrlsToUsersAgain < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :youtube_url, :string
    add_column :users, :twitch_url, :string
    add_column :users, :tiktok_url, :string
  end
end
