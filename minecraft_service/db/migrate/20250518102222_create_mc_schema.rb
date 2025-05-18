class CreateMcSchema < ActiveRecord::Migration[7.2]
  def change
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
end
