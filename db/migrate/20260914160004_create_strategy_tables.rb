class CreateStrategyTables < ActiveRecord::Migration[7.2]
  def change
    create_table :strategy_trees do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.text    :description
      t.integer :position, null: false, default: 0
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :discarded_at
      t.timestamps
    end
    add_index :strategy_trees, :slug, unique: true

    create_table :strategy_nodes do |t|
      t.references :strategy_tree, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :strategy_nodes }
      t.string  :title, null: false, limit: 120
      t.text    :note
      t.string  :color
      t.string  :icon
      t.integer :status, null: false, default: 0  # idea/pursuing/paused/achieved/dropped
      t.references :owner, foreign_key: { to_table: :users }
      t.decimal :position, precision: 20, scale: 10, null: false, default: 0
      t.integer :depth, null: false, default: 0
      t.boolean :collapsed, null: false, default: false
      t.integer :children_count, null: false, default: 0
      t.boolean :ai_generated, null: false, default: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      t.datetime :discarded_at
      t.timestamps
    end
    add_index :strategy_nodes, [:parent_id, :position]
    add_index :strategy_nodes, [:strategy_tree_id, :discarded_at]
    add_index :strategy_nodes, :depth

    create_table :strategy_snapshots do |t|
      t.references :strategy_tree, null: false, foreign_key: true
      t.string  :name, null: false
      t.jsonb   :payload, null: false, default: {}
      t.integer :node_count, null: false, default: 0
      t.boolean :auto, null: false, default: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end

    create_table :ai_suggestion_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :strategy_node, foreign_key: true
      t.integer :mode,   null: false, default: 0   # children / subtree
      t.text    :instruction
      t.jsonb   :suggestions, null: false, default: {}
      t.integer :accepted_count, null: false, default: 0
      t.integer :status, null: false, default: 0   # success / failed / cancelled
      t.integer :duration_ms
      t.timestamps
    end
    add_index :ai_suggestion_logs, [:user_id, :created_at]
  end
end
