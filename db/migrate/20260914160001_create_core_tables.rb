class CreateCoreTables < ActiveRecord::Migration[7.2]
  def change
    # ---- Không gian làm việc (bản ghi đơn) --------------------------------
    create_table :workspaces do |t|
      t.string  :name,     null: false, default: "Team Workspace"
      t.string  :tagline
      t.string  :timezone, null: false, default: "Asia/Ho_Chi_Minh"
      t.string  :currency, null: false, default: "VND"
      t.text    :about   # mô tả lĩnh vực của team — dùng làm ngữ cảnh cho AI
      t.timestamps
    end

    # ---- Người dùng -------------------------------------------------------
    create_table :users do |t|
      t.string   :email,              null: false, default: ""
      t.string   :encrypted_password, null: false, default: ""
      t.string   :full_name,          null: false, default: ""
      t.string   :job_title
      t.string   :phone
      t.integer  :role,               null: false, default: 0   # member / admin
      t.integer  :status,             null: false, default: 0   # invited / active / disabled

      # Lời mời (tự triển khai — SRS 5.2 users)
      t.string   :invitation_token
      t.datetime :invitation_sent_at
      t.datetime :invitation_accepted_at
      t.references :invited_by, foreign_key: { to_table: :users }

      # Devise :recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      # Devise :rememberable
      t.datetime :remember_created_at

      # Devise :trackable
      t.integer  :sign_in_count,      default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      # Devise :lockable — khoá 15 phút sau 10 lần sai
      t.integer  :failed_attempts,    default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      t.boolean  :daily_digest_enabled, null: false, default: true
      t.string   :avatar_color        # sinh tự động từ tên khi không có ảnh

      t.timestamps
    end
    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :invitation_token,     unique: true
    add_index :users, :unlock_token,         unique: true
    add_index :users, :status

    # ---- Dự án ------------------------------------------------------------
    create_table :projects do |t|
      t.string   :code,         null: false
      t.string   :name,         null: false
      t.text     :description
      t.integer  :project_type, null: false                 # product_sales / digital_transformation
      t.integer  :status,       null: false, default: 0     # planning / in_progress / on_hold / completed / cancelled
      t.string   :client_name
      t.date     :start_date
      t.date     :due_date
      t.datetime :completed_at
      t.integer  :progress_mode,   null: false, default: 0  # auto / manual
      t.integer  :manual_progress, null: false, default: 0
      t.string   :color
      t.references :owner,      foreign_key: { to_table: :users }
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :archived_at
      t.datetime :discarded_at
      t.timestamps
    end
    add_index :projects, :code, unique: true
    add_index :projects, :discarded_at
    add_index :projects, [:project_type, :status]

    create_table :project_memberships do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.datetime   :joined_at
      t.timestamps
    end
    add_index :project_memberships, [:project_id, :user_id], unique: true

    # ---- Cột Kanban -------------------------------------------------------
    create_table :board_columns do |t|
      t.references :project, null: false, foreign_key: true
      t.string  :name,  null: false
      t.string  :key,   null: false
      t.string  :color
      t.integer :position,  null: false, default: 0
      t.integer :wip_limit
      t.boolean :is_done_column, null: false, default: false
      t.timestamps
    end
    add_index :board_columns, [:project_id, :position]

    # ---- Nhãn -------------------------------------------------------------
    create_table :labels do |t|
      t.references :project, foreign_key: true   # nullable → nhãn toàn cục
      t.string :name,  null: false
      t.string :color, null: false, default: "#6B7A8F"
      t.timestamps
    end
    add_index :labels, [:project_id, :name], unique: true

    # ---- Công việc --------------------------------------------------------
    create_table :tasks do |t|
      t.references :project,       null: false, foreign_key: true
      t.references :board_column,  foreign_key: true
      t.string   :code,  null: false
      t.string   :title, null: false
      t.integer  :priority, null: false, default: 1   # low / medium / high / urgent
      t.references :assignee, foreign_key: { to_table: :users }
      t.references :reporter, foreign_key: { to_table: :users }
      t.date     :start_date
      t.date     :due_date
      t.decimal  :estimated_hours, precision: 6, scale: 2
      t.decimal  :position, precision: 20, scale: 10, null: false, default: 0
      t.integer  :status, null: false, default: 0     # open / done / cancelled
      t.datetime :completed_at
      t.datetime :discarded_at
      t.integer  :comments_count,    null: false, default: 0
      t.integer  :subtasks_count,    null: false, default: 0
      t.integer  :done_subtasks_count, null: false, default: 0
      t.timestamps
    end
    add_index :tasks, :code, unique: true
    add_index :tasks, [:project_id, :board_column_id, :position], name: "index_tasks_on_board_position"
    add_index :tasks, :due_date
    add_index :tasks, :discarded_at

    create_table :task_labels do |t|
      t.references :task,  null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true
    end
    add_index :task_labels, [:task_id, :label_id], unique: true

    create_table :subtasks do |t|
      t.references :task, null: false, foreign_key: true
      t.string  :title, null: false
      t.boolean :done,  null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    # ---- Bình luận --------------------------------------------------------
    create_table :comments do |t|
      t.references :commentable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.text     :body, null: false
      t.datetime :edited_at
      t.datetime :discarded_at
      t.timestamps
    end

    create_table :mentions do |t|
      t.references :comment, null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.datetime   :notified_at
      t.timestamps
    end
    add_index :mentions, [:comment_id, :user_id], unique: true
  end
end
