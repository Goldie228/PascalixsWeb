class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table "users", id: { type: :string, limit: 36, primary_key: true } do |t|
      t.text "about_me"
      t.boolean "is_added", default: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "otp_secret"
      t.integer "consumed_timestep"
      t.boolean "otp_required_for_login", default: false
      t.string "time_zone", default: "UTC"

      t.index ["is_added"], name: "index_users_on_is_added"
    end
  end
end
