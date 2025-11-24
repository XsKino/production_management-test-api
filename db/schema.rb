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

ActiveRecord::Schema[8.1].define(version: 2025_11_24_180951) do
  create_table "order_assignments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "production_order_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["production_order_id"], name: "index_order_assignments_on_production_order_id"
    t.index ["user_id", "production_order_id"], name: "index_order_assignments_on_user_id_and_production_order_id", unique: true
    t.index ["user_id"], name: "index_order_assignments_on_user_id"
  end

  create_table "order_audit_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "action", null: false
    t.text "change_details"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.bigint "production_order_id"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["action"], name: "index_order_audit_logs_on_action"
    t.index ["production_order_id", "created_at"], name: "index_order_audit_logs_on_production_order_id_and_created_at"
    t.index ["production_order_id"], name: "index_order_audit_logs_on_production_order_id"
    t.index ["user_id"], name: "index_order_audit_logs_on_user_id"
  end

  create_table "production_orders", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.date "deadline"
    t.date "expected_end_date", null: false
    t.integer "order_number", null: false
    t.date "start_date", null: false
    t.integer "status", default: 0, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_production_orders_on_creator_id"
    t.index ["type", "order_number"], name: "index_production_orders_on_type_and_order_number", unique: true
  end

  create_table "tasks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.date "expected_end_date", null: false
    t.bigint "production_order_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["production_order_id"], name: "index_tasks_on_production_order_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "order_assignments", "production_orders"
  add_foreign_key "order_assignments", "users"
  add_foreign_key "order_audit_logs", "production_orders"
  add_foreign_key "order_audit_logs", "users"
  add_foreign_key "production_orders", "users", column: "creator_id"
  add_foreign_key "tasks", "production_orders"
end
