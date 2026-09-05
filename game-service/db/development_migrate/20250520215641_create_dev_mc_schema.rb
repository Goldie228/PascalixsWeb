class CreateDevMcSchema < ActiveRecord::Migration[7.2]
  def change
    create_table "authme", id: { type: :integer, limit: 3, unsigned: true }, charset: "utf8mb3", collation: "utf8mb3_general_ci", if_not_exists: true do |t|
      t.string "username", null: false
      t.string "realname", null: false
      t.string "password", null: false, collation: "ascii_bin"
      t.string "ip", limit: 40, collation: "ascii_bin"
      t.bigint "lastlogin"
      t.float "x", limit: 53, default: 0.0, null: false
      t.float "y", limit: 53, default: 0.0, null: false
      t.float "z", limit: 53, default: 0.0, null: false
      t.string "world", default: "world", null: false
      t.bigint "regdate", default: 0, null: false
      t.string "regip", limit: 40, collation: "ascii_bin"
      t.float "yaw"
      t.float "pitch"
      t.string "email"
      t.integer "isLogged", limit: 2, default: 0, null: false
      t.integer "hasSession", limit: 2, default: 0, null: false
      t.string "totp", limit: 32
      t.index ["username"], name: "username", unique: true
    end

    create_table "luckperms_actions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", if_not_exists: true do |t|
      t.bigint "time", null: false
      t.string "actor_uuid", limit: 36, null: false
      t.string "actor_name", limit: 100, null: false
      t.string "type", limit: 1, null: false
      t.string "acted_uuid", limit: 36, null: false
      t.string "acted_name", limit: 36, null: false
      t.string "action", limit: 300, null: false
    end

    create_table "luckperms_group_permissions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", if_not_exists: true do |t|
      t.string "name", limit: 36, null: false
      t.string "permission", limit: 200, null: false
      t.boolean "value", null: false
      t.string "server", limit: 36, null: false
      t.string "world", limit: 64, null: false
      t.bigint "expiry", null: false
      t.string "contexts", limit: 200, null: false
      t.index ["name"], name: "luckperms_group_permissions_name"
    end

    create_table "luckperms_groups", primary_key: "name", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_general_ci", if_not_exists: true do |t|
      t.string "color", default: "#FFFFFF", null: false
    end

    create_table "luckperms_messenger", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", if_not_exists: true do |t|
      t.timestamp "time", default: -> { "current_timestamp() ON UPDATE current_timestamp()" }, null: false
      t.text "msg", null: false
    end

    create_table "luckperms_players", primary_key: "uuid", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_general_ci", if_not_exists: true do |t|
      t.string "username", limit: 16, null: false
      t.string "primary_group", limit: 36, null: false
      t.index ["username"], name: "luckperms_players_username"
    end

    create_table "luckperms_tracks", primary_key: "name", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_general_ci", if_not_exists: true do |t|
      t.text "groups", null: false
    end

    create_table "luckperms_user_permissions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", if_not_exists: true do |t|
      t.string "uuid", limit: 36, null: false
      t.string "permission", limit: 200, null: false
      t.boolean "value", null: false
      t.string "server", limit: 36, null: false
      t.string "world", limit: 64, null: false
      t.bigint "expiry", null: false
      t.string "contexts", limit: 200, null: false
      t.index ["uuid"], name: "luckperms_user_permissions_uuid"
    end
  end
end
