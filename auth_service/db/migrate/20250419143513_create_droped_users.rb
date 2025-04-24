class CreateDropedUsers < ActiveRecord::Migration[7.2]
  def change
    create_table "droped_users", id: false do |t|
      t.string "name", null: false, primary_key: true
      t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
  end
end
