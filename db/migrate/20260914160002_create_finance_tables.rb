class CreateFinanceTables < ActiveRecord::Migration[7.2]
  def change
    create_table :transaction_categories do |t|
      t.string  :name, null: false
      t.integer :kind, null: false          # income / expense
      t.boolean :is_active, null: false, default: true
      t.integer :position,  null: false, default: 0
      t.timestamps
    end
    add_index :transaction_categories, [:kind, :name], unique: true

    create_table :transactions do |t|
      t.integer :kind,   null: false                      # income (Thu) / expense (Chi)
      t.bigint  :amount, null: false                      # VND, số nguyên, luôn dương
      t.date    :occurred_on, null: false
      t.references :category, foreign_key: { to_table: :transaction_categories }
      t.references :project,  foreign_key: true           # nullable → chung workspace
      t.string  :description
      t.string  :counterparty
      t.integer :payment_method, null: false, default: 1  # cash / bank_transfer / card / other
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :discarded_at
      t.timestamps
    end
    add_index :transactions, :occurred_on
    add_index :transactions, [:project_id, :kind]
    add_index :transactions, :discarded_at
  end
end
