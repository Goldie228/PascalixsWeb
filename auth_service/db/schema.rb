# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_05_17_234010) do
  create_table "discord_accounts", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "user_id", limit: 36, null: false
    t.string "discord_id", null: false
    t.string "username", null: false
    t.string "discriminator"
    t.string "email", null: false
    t.string "avatar", null: false
    t.index ["discord_id"], name: "index_discord_accounts_on_discord_id", unique: true
    t.index ["user_id"], name: "index_discord_accounts_on_user_id", unique: true
    t.index ["username"], name: "index_discord_accounts_on_username"
  end

  create_table "droped_users", primary_key: "name", id: :string, force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "minecraft_accounts", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "user_id", limit: 36, null: false
    t.string "nickname", null: false
    t.string "password_hash", null: false
    t.index ["nickname"], name: "index_minecraft_accounts_on_nickname", unique: true
    t.index ["user_id"], name: "index_minecraft_accounts_on_user_id", unique: true
  end

  create_table "users", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.boolean "is_added", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "otp_secret"
    t.integer "consumed_timestep"
    t.boolean "otp_required_for_login", default: false
    t.string "time_zone", default: "UTC"
    t.text "about_me"
    t.index ["is_added"], name: "index_users_on_is_added"
  end

  add_foreign_key "discord_accounts", "users"
  add_foreign_key "minecraft_accounts", "users"
end
