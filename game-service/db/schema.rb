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

ActiveRecord::Schema[8.1].define(version: 2025_05_20_215641) do
  create_table "authme", force: :cascade do |t|
    t.string "email"
    t.integer "hasSession", default: 0, null: false
    t.string "ip", limit: 40
    t.integer "isLogged", default: 0, null: false
    t.bigint "lastlogin"
    t.string "password", null: false
    t.float "pitch"
    t.string "realname", null: false
    t.bigint "regdate", default: 0, null: false
    t.string "regip", limit: 40
    t.string "totp", limit: 32
    t.string "username", null: false
    t.string "world", default: "world", null: false
    t.float "x", default: 0.0, null: false
    t.float "y", default: 0.0, null: false
    t.float "yaw"
    t.float "z", default: 0.0, null: false
    t.index ["username"], name: "username", unique: true
  end

  create_table "luckperms_actions", force: :cascade do |t|
    t.string "acted_name", limit: 36, null: false
    t.string "acted_uuid", limit: 36, null: false
    t.string "action", limit: 300, null: false
    t.string "actor_name", limit: 100, null: false
    t.string "actor_uuid", limit: 36, null: false
    t.bigint "time", null: false
    t.string "type", limit: 1, null: false
  end

  create_table "luckperms_group_permissions", force: :cascade do |t|
    t.string "contexts", limit: 200, null: false
    t.bigint "expiry", null: false
    t.string "name", limit: 36, null: false
    t.string "permission", limit: 200, null: false
    t.string "server", limit: 36, null: false
    t.boolean "value", null: false
    t.string "world", limit: 64, null: false
    t.index ["name"], name: "luckperms_group_permissions_name"
  end

  create_table "luckperms_groups", primary_key: "name", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "color", default: "#FFFFFF", null: false
  end

  create_table "luckperms_messenger", force: :cascade do |t|
    t.text "msg", null: false
    t.datetime "time", null: false
  end

  create_table "luckperms_players", primary_key: "uuid", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "primary_group", limit: 36, null: false
    t.string "username", limit: 16, null: false
    t.index ["username"], name: "luckperms_players_username"
  end

  create_table "luckperms_tracks", primary_key: "name", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.text "groups", null: false
  end

  create_table "luckperms_user_permissions", force: :cascade do |t|
    t.string "contexts", limit: 200, null: false
    t.bigint "expiry", null: false
    t.string "permission", limit: 200, null: false
    t.string "server", limit: 36, null: false
    t.string "uuid", limit: 36, null: false
    t.boolean "value", null: false
    t.string "world", limit: 64, null: false
    t.index ["uuid"], name: "luckperms_user_permissions_uuid"
  end
end
