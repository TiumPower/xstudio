class CreateActivityTables < ActiveRecord::Migration[7.2]
  def change
    create_table :activities do |t|
      t.references :user, foreign_key: true
      t.string  :action, null: false
      t.references :trackable, polymorphic: true
      t.references :project, foreign_key: true
      t.string  :summary                    # câu mô tả tiếng Việt đã dựng sẵn
      t.jsonb   :changes_payload, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :activities, :created_at

    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string   :event_type, null: false
      t.string   :title, null: false
      t.string   :body
      t.string   :url
      t.references :actor, foreign_key: { to_table: :users }
      t.datetime :read_at
      t.datetime :emailed_at
      t.datetime :created_at, null: false
    end
    add_index :notifications, [:user_id, :read_at]

    create_table :notification_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :event_type,     null: false
      t.boolean :email_enabled,  null: false, default: true
      t.boolean :in_app_enabled, null: false, default: true
      t.timestamps
    end
    add_index :notification_settings, [:user_id, :event_type], unique: true
  end
end
