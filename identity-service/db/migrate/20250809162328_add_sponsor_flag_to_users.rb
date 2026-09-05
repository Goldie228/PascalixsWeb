class AddSponsorFlagToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :is_sponsor, :boolean, default: false, null: false
    add_index  :users, :is_sponsor
  end
end
