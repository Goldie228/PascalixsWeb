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

ActiveRecord::Schema[8.1].define(version: 2026_09_04_000002) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", limit: 36, null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "discord_accounts", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "avatar", null: false
    t.string "discord_id", null: false
    t.string "discriminator"
    t.string "email", null: false
    t.string "user_id", limit: 36, null: false
    t.string "username", null: false
    t.index ["discord_id"], name: "index_discord_accounts_on_discord_id", unique: true
    t.index ["user_id"], name: "index_discord_accounts_on_user_id", unique: true
    t.index ["username"], name: "index_discord_accounts_on_username"
  end

  create_table "discord_avatars", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "discord_account_id", limit: 36, null: false
    t.string "original_url"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_discord_avatars_on_created_at"
    t.index ["discord_account_id"], name: "index_discord_avatars_on_discord_account_id"
    t.index ["status"], name: "index_discord_avatars_on_status"
  end

  create_table "droped_users", primary_key: "name", id: :string, force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "galleries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "published", default: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["published"], name: "index_galleries_on_published"
  end

  create_table "minecraft_accounts", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "nickname", null: false
    t.string "password_hash", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["nickname"], name: "index_minecraft_accounts_on_nickname", unique: true
    t.index ["user_id"], name: "index_minecraft_accounts_on_user_id", unique: true
  end

  create_table "photos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "gallery_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["gallery_id"], name: "index_photos_on_gallery_id"
    t.index ["title"], name: "index_photos_on_title"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "price", precision: 10, scale: 2
    t.string "product_type"
    t.datetime "updated_at", null: false
    t.index ["product_type"], name: "index_products_on_product_type", unique: true
  end

  create_table "punishment_reasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.decimal "price", precision: 10, scale: 2, default: "1.0", null: false
    t.string "punishment_type", null: false
    t.integer "rule_number", null: false
    t.datetime "updated_at", null: false
    t.index ["punishment_type", "rule_number"], name: "idx_reason_type_rule_unique", unique: true
    t.index ["rule_number"], name: "index_punishment_reasons_on_rule_number"
  end

  create_table "purchases", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 8, default: "BYN", null: false
    t.json "metadata", default: {}, null: false
    t.integer "punishment_id"
    t.string "purchase_type", null: false
    t.string "purchaser_user_id", limit: 36, null: false
    t.string "review_comment", limit: 500
    t.datetime "reviewed_at"
    t.string "reviewed_by_user_id", limit: 36
    t.string "status", default: "pending", null: false
    t.string "target_user_id", limit: 36
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_purchases_on_created_at"
    t.index ["punishment_id"], name: "index_purchases_on_punishment_id"
    t.index ["purchase_type"], name: "index_purchases_on_purchase_type"
    t.index ["purchaser_user_id"], name: "index_purchases_on_purchaser_user_id"
    t.index ["status"], name: "index_purchases_on_status"
    t.index ["target_user_id"], name: "index_purchases_on_target_user_id"
    t.check_constraint "amount >= 0", name: "amount_non_negative"
  end

  create_table "report_attachments", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.bigint "file_size", null: false
    t.string "filename", null: false
    t.datetime "updated_at", null: false
    t.string "user_report_id", limit: 36, null: false
    t.index ["id"], name: "index_report_attachments_on_id", unique: true
    t.index ["user_report_id"], name: "index_report_attachments_on_user_report_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "color", null: false
    t.string "name", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "user_punishment_appeals", force: :cascade do |t|
    t.string "admin_comment", limit: 500
    t.boolean "can_reappeal", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "punishment_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "user_message", limit: 500
    t.index ["punishment_id"], name: "index_user_punishment_appeals_on_punishment_id", unique: true
  end

  create_table "user_reports", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", limit: 5000, null: false
    t.boolean "is_active", default: true, null: false
    t.string "reported_user_id", null: false
    t.string "reporter_id", null: false
    t.string "title", limit: 80, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_user_reports_on_created_at"
    t.index ["is_active"], name: "index_user_reports_on_is_active"
    t.index ["reported_user_id"], name: "index_user_reports_on_reported_user_id"
    t.index ["reporter_id"], name: "index_user_reports_on_reporter_id"
  end

  create_table "users", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.text "about_me"
    t.integer "consumed_timestep"
    t.datetime "created_at", null: false
    t.boolean "is_added", default: false
    t.boolean "is_sponsor", default: false, null: false
    t.boolean "otp_required_for_login", default: false
    t.string "otp_secret"
    t.integer "role_id", default: 1, null: false
    t.string "tiktok_channel_name"
    t.string "tiktok_url"
    t.string "time_zone", default: "UTC"
    t.string "twitch_channel_name"
    t.string "twitch_url"
    t.datetime "updated_at", null: false
    t.string "youtube_channel_name"
    t.string "youtube_url"
    t.index ["is_added"], name: "index_users_on_is_added"
    t.index ["is_sponsor"], name: "index_users_on_is_sponsor"
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "users_punishments", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "bad_user_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.integer "duration"
    t.datetime "expires_at"
    t.datetime "issued_at", null: false
    t.integer "punishment_reason_id"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.decimal "withdrawal_price", precision: 10, scale: 2
    t.index ["active"], name: "index_users_punishments_on_active"
    t.index ["bad_user_id"], name: "index_users_punishments_on_bad_user_id"
    t.index ["issued_at"], name: "index_users_punishments_on_issued_at"
    t.index ["punishment_reason_id"], name: "index_users_punishments_on_punishment_reason_id"
    t.index ["user_id"], name: "index_users_punishments_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "discord_avatars", "discord_accounts"
  add_foreign_key "discord_avatars", "discord_accounts"
  add_foreign_key "photos", "galleries"
  add_foreign_key "photos", "galleries"
  add_foreign_key "purchases", "users", column: "purchaser_user_id"
  add_foreign_key "purchases", "users", column: "purchaser_user_id"
  add_foreign_key "purchases", "users", column: "target_user_id"
  add_foreign_key "purchases", "users", column: "target_user_id"
  add_foreign_key "purchases", "users_punishments", column: "punishment_id"
  add_foreign_key "purchases", "users_punishments", column: "punishment_id"
  add_foreign_key "report_attachments", "user_reports"
  add_foreign_key "user_punishment_appeals", "users_punishments", column: "punishment_id"
  add_foreign_key "user_punishment_appeals", "users_punishments", column: "punishment_id"
  add_foreign_key "user_reports", "users", column: "reported_user_id"
  add_foreign_key "user_reports", "users", column: "reported_user_id"
  add_foreign_key "user_reports", "users", column: "reporter_id"
  add_foreign_key "user_reports", "users", column: "reporter_id"
  add_foreign_key "users", "roles"
  add_foreign_key "users_punishments", "punishment_reasons"
  add_foreign_key "users_punishments", "users"
  add_foreign_key "users_punishments", "users"
  add_foreign_key "users_punishments", "users", column: "bad_user_id"
  add_foreign_key "users_punishments", "users", column: "bad_user_id"
end
