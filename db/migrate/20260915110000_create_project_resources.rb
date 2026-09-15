class CreateProjectResources < ActiveRecord::Migration[7.2]
  # Dự án loại "Products" là sản phẩm của chính đội, nên cần chỗ gom: đường
  # dẫn tới trang/kho mã/thiết kế, tài khoản dùng để truy cập, và tài liệu.
  #
  # CỐ Ý KHÔNG có cột mật khẩu. Đây là nơi ghi chép "dùng tài khoản nào",
  # không phải kho mật khẩu — mật khẩu dùng chung thuộc về trình quản lý
  # mật khẩu, nơi có kiểm soát truy cập và nhật ký riêng.
  def change
    create_table :project_resources do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :kind,  null: false, default: 0   # link / account / doc
      t.string  :label, null: false
      t.string  :url
      t.string  :username                          # tài khoản dùng để đăng nhập
      t.text    :note
      t.integer :position, null: false, default: 0
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :project_resources, [:project_id, :kind, :position]
  end
end
