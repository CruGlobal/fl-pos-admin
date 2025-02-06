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

ActiveRecord::Schema[8.0].define(version: 2025_02_04_225248) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "jobs", force: :cascade do |t|
    t.integer "status"
    t.string "event_code"
    t.date "start_date"
    t.date "end_date"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.jsonb "context", default: {}, null: false
    t.bigint "shop_id"
    t.index ["context"], name: "index_jobs_on_context", using: :gin
  end

  create_table "logs", force: :cascade do |t|
    t.text "content"
    t.bigint "jobs_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jobs_id"], name: "index_logs_on_jobs_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "woo_product_bundles", force: :cascade do |t|
    t.bigint "product_id"
    t.bigint "bundled_product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "default_quantity", default: 0
  end

  create_table "woo_products", force: :cascade do |t|
    t.string "sku"
    t.bigint "product_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
  end

  add_foreign_key "logs", "jobs", column: "jobs_id"
  add_foreign_key "woo_product_bundles", "woo_products", column: "product_id"
end
