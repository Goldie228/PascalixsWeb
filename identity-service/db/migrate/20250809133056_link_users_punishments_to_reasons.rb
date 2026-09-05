class LinkUsersPunishmentsToReasons < ActiveRecord::Migration[7.2]
  def change
    remove_column :users_punishments, :reason, :text
    add_reference :users_punishments, :punishment_reason, null: true, foreign_key: true, index: true
  end
end
