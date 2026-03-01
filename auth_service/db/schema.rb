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

ActiveRecord::Schema[7.2].define(version: 2026_02_28_093317) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.string "record_id", limit: 36, null: false
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

  create_table "discord_avatars", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "discord_account_id", limit: 36, null: false
    t.string "status", default: "pending", null: false
    t.string "original_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_discord_avatars_on_created_at"
    t.index ["discord_account_id"], name: "index_discord_avatars_on_discord_account_id"
    t.index ["status"], name: "index_discord_avatars_on_status"
  end

  create_table "droped_users", primary_key: "name", id: :string, force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "galleries", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published", default: false
    t.index ["published"], name: "index_galleries_on_published"
  end

  create_table "minecraft_accounts", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "user_id", limit: 36, null: false
    t.string "nickname", null: false
    t.string "password_hash", null: false
    t.index ["nickname"], name: "index_minecraft_accounts_on_nickname", unique: true
    t.index ["user_id"], name: "index_minecraft_accounts_on_user_id", unique: true
  end

  create_table "photos", force: :cascade do |t|
    t.integer "gallery_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gallery_id"], name: "index_photos_on_gallery_id"
    t.index ["title"], name: "index_photos_on_title"
  end

  create_table "products", force: :cascade do |t|
    t.string "product_type"
    t.decimal "price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_type"], name: "index_products_on_product_type", unique: true
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

  create_table "purchases", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "purchaser_user_id", limit: 36, null: false
    t.string "target_user_id", limit: 36
    t.string "purchase_type", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "currency", limit: 8, default: "BYN", null: false
    t.integer "punishment_id"
    t.string "status", default: "pending", null: false
    t.string "review_comment", limit: 500
    t.string "reviewed_by_user_id", limit: 36
    t.datetime "reviewed_at"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
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
    t.boolean "is_sponsor", default: false, null: false
    t.index ["is_added"], name: "index_users_on_is_added"
    t.index ["is_sponsor"], name: "index_users_on_is_sponsor"
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

  create_table "wiki_categories", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "parent_id", limit: 36
    t.index ["parent_id"], name: "index_wiki_categories_on_parent_id"
    t.index ["slug"], name: "index_wiki_categories_on_slug", unique: true
  end

  create_table "wiki_downloads", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "wiki_page_id", limit: 36, null: false
    t.string "title", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["wiki_page_id"], name: "index_wiki_downloads_on_wiki_page_id"
  end

  create_table "wiki_pages", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "content", null: false
    t.boolean "published", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "wiki_category_id", limit: 36
    t.index ["published"], name: "index_wiki_pages_on_wiki_category_id_and_published"
    t.index ["slug"], name: "index_wiki_pages_on_slug", unique: true
    t.index ["wiki_category_id"], name: "index_wiki_pages_on_wiki_category_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "discord_avatars", "discord_accounts"
  add_foreign_key "photos", "galleries"
  add_foreign_key "purchases", "users", column: "purchaser_user_id"
  add_foreign_key "purchases", "users", column: "target_user_id"
  add_foreign_key "purchases", "users_punishments", column: "punishment_id"
  add_foreign_key "report_attachments", "user_reports"
  add_foreign_key "user_punishment_appeals", "users_punishments", column: "punishment_id"
  add_foreign_key "user_reports", "users", column: "reported_user_id"
  add_foreign_key "user_reports", "users", column: "reporter_id"
  add_foreign_key "users", "roles"
  add_foreign_key "users_punishments", "punishment_reasons"
  add_foreign_key "users_punishments", "users"
  add_foreign_key "users_punishments", "users", column: "bad_user_id"
  add_foreign_key "wiki_downloads", "wiki_pages", on_delete: :cascade
  add_foreign_key "wiki_pages", "wiki_categories", on_delete: :nullify
end
