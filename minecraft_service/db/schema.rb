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

ActiveRecord::Schema[7.2].define(version: 2025_05_18_102222) do
  create_table "authme", force: :cascade do |t|
    t.text "username", null: false
    t.text "realname", null: false
    t.text "password", null: false
    t.text "ip"
    t.integer "lastlogin"
    t.float "x", default: 0.0, null: false
    t.float "y", default: 0.0, null: false
    t.float "z", default: 0.0, null: false
    t.text "world", default: "world", null: false
    t.integer "regdate", default: 0, null: false
    t.text "regip"
    t.float "yaw"
    t.float "pitch"
    t.text "email"
    t.integer "isLogged", default: 0, null: false
    t.integer "hasSession", default: 0, null: false
    t.text "totp"
  end

  create_table "luckperms_actions", force: :cascade do |t|
    t.integer "time", null: false
    t.text "actor_uuid", null: false
    t.text "actor_name", null: false
    t.text "type", null: false
    t.text "acted_uuid", null: false
    t.text "acted_name", null: false
    t.text "action", null: false
  end

  create_table "luckperms_group_permissions", force: :cascade do |t|
    t.text "name", null: false
    t.text "permission", null: false
    t.integer "value", null: false
    t.text "server", null: false
    t.text "world", null: false
    t.integer "expiry", null: false
    t.text "contexts", null: false
    t.index ["name"], name: "idx_luckperms_group_permissions_name"
  end

  create_table "luckperms_groups", primary_key: "name", id: :text, force: :cascade do |t|
  end

  create_table "luckperms_messenger", force: :cascade do |t|
    t.datetime "time", precision: nil, null: false
    t.text "msg", null: false
  end

  create_table "luckperms_players", primary_key: "uuid", id: :text, force: :cascade do |t|
    t.text "username", null: false
    t.text "primary_group", null: false
    t.index ["username"], name: "idx_luckperms_players_username"
  end

  create_table "luckperms_tracks", primary_key: "name", id: :text, force: :cascade do |t|
    t.text "groups", null: false
  end

  create_table "luckperms_user_permissions", force: :cascade do |t|
    t.text "uuid", null: false
    t.text "permission", null: false
    t.integer "value", null: false
    t.text "server", null: false
    t.text "world", null: false
    t.integer "expiry", null: false
    t.text "contexts", null: false
    t.index ["uuid"], name: "idx_luckperms_user_permissions_uuid"
  end
end
