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

ActiveRecord::Schema[7.2].define(version: 2025_08_09_133056) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "punishment_reasons", force: :cascade do |t|
    t.string "punishment_type", null: false
    t.text "description", null: false
    t.integer "rule_number", null: false
    t.decimal "price", precision: 10, scale: 2, default: "1.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["punishment_type", "rule_number"], name: "idx_reason_type_rule_unique", unique: true
    t.index ["rule_number"], name: "index_punishment_reasons_on_rule_number"
  end

  create_table "report_attachments", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "user_report_id", limit: 36, null: false
    t.string "filename", null: false
    t.string "content_type", null: false
    t.bigint "file_size", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_report_attachments_on_id", unique: true
    t.index ["user_report_id"], name: "index_report_attachments_on_user_report_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "user_punishment_appeals", force: :cascade do |t|
    t.integer "punishment_id", null: false
    t.string "user_message", limit: 500
    t.string "admin_comment", limit: 500
    t.string "status", default: "pending", null: false
    t.boolean "can_reappeal", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["punishment_id"], name: "index_user_punishment_appeals_on_punishment_id", unique: true
  end

  create_table "user_reports", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "reporter_id", null: false
    t.string "reported_user_id", null: false
    t.string "title", limit: 80, null: false
    t.text "description", limit: 5000, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_user_reports_on_is_active"
    t.index ["reported_user_id"], name: "index_user_reports_on_reported_user_id"
    t.index ["reporter_id"], name: "index_user_reports_on_reporter_id"
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
    t.integer "role_id", default: 1, null: false
    t.string "youtube_url"
    t.string "twitch_url"
    t.string "tiktok_url"
    t.string "youtube_channel_name"
    t.string "twitch_channel_name"
    t.string "tiktok_channel_name"
    t.index ["is_added"], name: "index_users_on_is_added"
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "users_punishments", force: :cascade do |t|
    t.string "user_id", limit: 36, null: false
    t.string "bad_user_id", limit: 36, null: false
    t.string "type", null: false
    t.decimal "withdrawal_price", precision: 10, scale: 2
    t.datetime "issued_at", null: false
    t.integer "duration"
    t.datetime "expires_at"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "punishment_reason_id"
    t.index ["punishment_reason_id"], name: "index_users_punishments_on_punishment_reason_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "report_attachments", "user_reports"
  add_foreign_key "user_punishment_appeals", "users_punishments", column: "punishment_id"
  add_foreign_key "user_reports", "users", column: "reported_user_id"
  add_foreign_key "user_reports", "users", column: "reporter_id"
  add_foreign_key "users", "roles"
  add_foreign_key "users_punishments", "punishment_reasons"
  add_foreign_key "users_punishments", "users"
  add_foreign_key "users_punishments", "users", column: "bad_user_id"
end
