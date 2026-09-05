class AddAboutMeToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :about_me, :text
  end
end
