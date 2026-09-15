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

ActiveRecord::Schema[7.2].define(version: 2026_09_15_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "unaccent"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "activities", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "trackable_type"
    t.bigint "trackable_id"
    t.bigint "project_id"
    t.string "summary"
    t.jsonb "changes_payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_activities_on_created_at"
    t.index ["project_id"], name: "index_activities_on_project_id"
    t.index ["trackable_type", "trackable_id"], name: "index_activities_on_trackable"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "ai_suggestion_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "strategy_node_id"
    t.integer "mode", default: 0, null: false
    t.text "instruction"
    t.jsonb "suggestions", default: {}, null: false
    t.integer "accepted_count", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "duration_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["strategy_node_id"], name: "index_ai_suggestion_logs_on_strategy_node_id"
    t.index ["user_id", "created_at"], name: "index_ai_suggestion_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_suggestion_logs_on_user_id"
  end

  create_table "board_columns", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "key", null: false
    t.string "color"
    t.integer "position", default: 0, null: false
    t.integer "wip_limit"
    t.boolean "is_done_column", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "position"], name: "index_board_columns_on_project_id_and_position"
    t.index ["project_id"], name: "index_board_columns_on_project_id"
  end

  create_table "comments", force: :cascade do |t|
    t.string "commentable_type", null: false
    t.bigint "commentable_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.datetime "edited_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "labels", force: :cascade do |t|
    t.bigint "project_id"
    t.string "name", null: false
    t.string "color", default: "#6B7A8F", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_labels_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_labels_on_project_id"
  end

  create_table "mentions", force: :cascade do |t|
    t.bigint "comment_id", null: false
    t.bigint "user_id", null: false
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id", "user_id"], name: "index_mentions_on_comment_id_and_user_id", unique: true
    t.index ["comment_id"], name: "index_mentions_on_comment_id"
    t.index ["user_id"], name: "index_mentions_on_user_id"
  end

  create_table "notification_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "event_type", null: false
    t.boolean "email_enabled", default: true, null: false
    t.boolean "in_app_enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "event_type"], name: "index_notification_settings_on_user_id_and_event_type", unique: true
    t.index ["user_id"], name: "index_notification_settings_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "event_type", null: false
    t.string "title", null: false
    t.string "body"
    t.string "url"
    t.bigint "actor_id"
    t.datetime "read_at"
    t.datetime "emailed_at"
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "project_memberships", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.datetime "joined_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "project_resources", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.integer "kind", default: 0, null: false
    t.string "label", null: false
    t.string "url"
    t.string "username"
    t.text "note"
    t.integer "position", default: 0, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_project_resources_on_created_by_id"
    t.index ["project_id", "kind", "position"], name: "index_project_resources_on_project_id_and_kind_and_position"
    t.index ["project_id"], name: "index_project_resources_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "project_type", null: false
    t.integer "status", default: 0, null: false
    t.string "client_name"
    t.date "start_date"
    t.date "due_date"
    t.datetime "completed_at"
    t.integer "progress_mode", default: 0, null: false
    t.integer "manual_progress", default: 0, null: false
    t.string "color"
    t.bigint "owner_id"
    t.bigint "created_by_id"
    t.datetime "archived_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_projects_on_code", unique: true
    t.index ["created_by_id"], name: "index_projects_on_created_by_id"
    t.index ["discarded_at"], name: "index_projects_on_discarded_at"
    t.index ["owner_id"], name: "index_projects_on_owner_id"
    t.index ["project_type", "status"], name: "index_projects_on_project_type_and_status"
  end

  create_table "strategy_nodes", force: :cascade do |t|
    t.bigint "strategy_tree_id", null: false
    t.bigint "parent_id"
    t.string "title", limit: 120, null: false
    t.text "note"
    t.string "color"
    t.string "icon"
    t.integer "status", default: 0, null: false
    t.bigint "owner_id"
    t.decimal "position", precision: 20, scale: 10, default: "0.0", null: false
    t.integer "depth", default: 0, null: false
    t.boolean "collapsed", default: false, null: false
    t.integer "children_count", default: 0, null: false
    t.boolean "ai_generated", default: false, null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_strategy_nodes_on_created_by_id"
    t.index ["depth"], name: "index_strategy_nodes_on_depth"
    t.index ["owner_id"], name: "index_strategy_nodes_on_owner_id"
    t.index ["parent_id", "position"], name: "index_strategy_nodes_on_parent_id_and_position"
    t.index ["parent_id"], name: "index_strategy_nodes_on_parent_id"
    t.index ["strategy_tree_id", "discarded_at"], name: "index_strategy_nodes_on_strategy_tree_id_and_discarded_at"
    t.index ["strategy_tree_id"], name: "index_strategy_nodes_on_strategy_tree_id"
    t.index ["updated_by_id"], name: "index_strategy_nodes_on_updated_by_id"
  end

  create_table "strategy_snapshots", force: :cascade do |t|
    t.bigint "strategy_tree_id", null: false
    t.string "name", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "node_count", default: 0, null: false
    t.boolean "auto", default: false, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.index ["created_by_id"], name: "index_strategy_snapshots_on_created_by_id"
    t.index ["strategy_tree_id"], name: "index_strategy_snapshots_on_strategy_tree_id"
  end

  create_table "strategy_trees", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.bigint "created_by_id"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_strategy_trees_on_created_by_id"
    t.index ["slug"], name: "index_strategy_trees_on_slug", unique: true
  end

  create_table "subtasks", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "title", null: false
    t.boolean "done", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_subtasks_on_task_id"
  end

  create_table "task_labels", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "label_id", null: false
    t.index ["label_id"], name: "index_task_labels_on_label_id"
    t.index ["task_id", "label_id"], name: "index_task_labels_on_task_id_and_label_id", unique: true
    t.index ["task_id"], name: "index_task_labels_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "board_column_id"
    t.string "code", null: false
    t.string "title", null: false
    t.integer "priority", default: 1, null: false
    t.bigint "assignee_id"
    t.bigint "reporter_id"
    t.date "start_date"
    t.date "due_date"
    t.decimal "estimated_hours", precision: 6, scale: 2
    t.decimal "position", precision: 20, scale: 10, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "discarded_at"
    t.integer "comments_count", default: 0, null: false
    t.integer "subtasks_count", default: 0, null: false
    t.integer "done_subtasks_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["board_column_id"], name: "index_tasks_on_board_column_id"
    t.index ["code"], name: "index_tasks_on_code", unique: true
    t.index ["discarded_at"], name: "index_tasks_on_discarded_at"
    t.index ["due_date"], name: "index_tasks_on_due_date"
    t.index ["project_id", "board_column_id", "position"], name: "index_tasks_on_board_position"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["reporter_id"], name: "index_tasks_on_reporter_id"
  end

  create_table "transaction_categories", force: :cascade do |t|
    t.string "name", null: false
    t.integer "kind", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind", "name"], name: "index_transaction_categories_on_kind_and_name", unique: true
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "kind", null: false
    t.bigint "amount", null: false
    t.date "occurred_on", null: false
    t.bigint "category_id"
    t.bigint "project_id"
    t.string "description"
    t.string "counterparty"
    t.integer "payment_method", default: 1, null: false
    t.bigint "created_by_id"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["created_by_id"], name: "index_transactions_on_created_by_id"
    t.index ["discarded_at"], name: "index_transactions_on_discarded_at"
    t.index ["occurred_on"], name: "index_transactions_on_occurred_on"
    t.index ["project_id", "kind"], name: "index_transactions_on_project_id_and_kind"
    t.index ["project_id"], name: "index_transactions_on_project_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "full_name", default: "", null: false
    t.string "job_title"
    t.string "phone"
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "invitation_token"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.bigint "invited_by_id"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.boolean "daily_digest_enabled", default: true, null: false
    t.string "avatar_color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "session_token"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["status"], name: "index_users_on_status"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", default: "Team Workspace", null: false
    t.string "tagline"
    t.string "timezone", default: "Asia/Ho_Chi_Minh", null: false
    t.string "currency", default: "VND", null: false
    t.text "about"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "projects"
  add_foreign_key "activities", "users"
  add_foreign_key "ai_suggestion_logs", "strategy_nodes"
  add_foreign_key "ai_suggestion_logs", "users"
  add_foreign_key "board_columns", "projects"
  add_foreign_key "comments", "users"
  add_foreign_key "labels", "projects"
  add_foreign_key "mentions", "comments"
  add_foreign_key "mentions", "users"
  add_foreign_key "notification_settings", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "project_resources", "projects"
  add_foreign_key "project_resources", "users", column: "created_by_id"
  add_foreign_key "projects", "users", column: "created_by_id"
  add_foreign_key "projects", "users", column: "owner_id"
  add_foreign_key "strategy_nodes", "strategy_nodes", column: "parent_id"
  add_foreign_key "strategy_nodes", "strategy_trees"
  add_foreign_key "strategy_nodes", "users", column: "created_by_id"
  add_foreign_key "strategy_nodes", "users", column: "owner_id"
  add_foreign_key "strategy_nodes", "users", column: "updated_by_id"
  add_foreign_key "strategy_snapshots", "strategy_trees"
  add_foreign_key "strategy_snapshots", "users", column: "created_by_id"
  add_foreign_key "strategy_trees", "users", column: "created_by_id"
  add_foreign_key "subtasks", "tasks"
  add_foreign_key "task_labels", "labels"
  add_foreign_key "task_labels", "tasks"
  add_foreign_key "tasks", "board_columns"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "users", column: "assignee_id"
  add_foreign_key "tasks", "users", column: "reporter_id"
  add_foreign_key "transactions", "projects"
  add_foreign_key "transactions", "transaction_categories", column: "category_id"
  add_foreign_key "transactions", "users", column: "created_by_id"
  add_foreign_key "users", "users", column: "invited_by_id"
end
