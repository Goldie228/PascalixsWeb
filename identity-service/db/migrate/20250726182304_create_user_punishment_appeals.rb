class CreateUserPunishmentAppeals < ActiveRecord::Migration[7.2]
  def change
    create_table :user_punishment_appeals do |t|
      t.integer :punishment_id, null: false

      t.string  :user_message, limit: 500
      t.string  :admin_comment, limit: 500

      t.string  :status, default: 'pending', null: false
      t.boolean :can_reappeal, default: true, null: false

      t.timestamps
    end

    add_foreign_key :user_punishment_appeals, :users_punishments, column: :punishment_id
    add_index :user_punishment_appeals, :punishment_id, unique: true
  end
end
