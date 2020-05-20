# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_04_17_030553) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "consumer_events", id: :serial, force: :cascade do |t|
    t.integer "consumer_id", null: false
    t.integer "event_type_id", null: false
    t.integer "article_id"
    t.integer "notification_id"
    t.string "language"
    t.string "search_phrase"
    t.integer "length"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_consumer_events_on_article_id"
    t.index ["consumer_id"], name: "index_consumer_events_on_consumer_id"
    t.index ["event_type_id"], name: "index_consumer_events_on_event_type_id"
    t.index ["notification_id"], name: "index_consumer_events_on_notification_id"
  end

  create_table "consumers", id: :serial, force: :cascade do |t|
    t.string "uuid", null: false
    t.datetime "last_seen", null: false
    t.integer "times_seen", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uuid"], name: "index_consumers_on_uuid", unique: true
  end

  create_table "notifications", id: :serial, force: :cascade do |t|
    t.text "message"
    t.string "language"
    t.integer "reach"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "push_time"
    t.string "article_id"
    t.string "headline"
  end

  create_table "push_devices", id: :serial, force: :cascade do |t|
    t.string "dev_token"
    t.string "dev_id"
    t.string "language"
    t.string "platform"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
  end

  create_table "settings", id: :serial, force: :cascade do |t|
    t.string "var", null: false
    t.text "value"
    t.integer "thing_id"
    t.string "thing_type", limit: 30
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["thing_type", "thing_id", "var"], name: "index_settings_on_thing_type_and_thing_id_and_var", unique: true
  end

  create_table "sn_works_ceos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subscription_users", force: :cascade do |t|
    t.string "username", null: false
    t.string "api_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "{:index=>true, :foreign_key=>true}_id"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["{:index=>true, :foreign_key=>true}_id"], name: "index_users_on_{:index=>true, :foreign_key=>true}_id"
  end

end
