class AddSessionTokenToUsers < ActiveRecord::Migration[7.2]
  # Devise dựng khoá phiên từ `authenticatable_salt`, mặc định lấy từ
  # encrypted_password. Muốn "đăng xuất khỏi mọi thiết bị" mà KHÔNG bắt đổi
  # mật khẩu thì phải có thêm một mẩu riêng để đổi — chính là cột này.
  def change
    add_column :users, :session_token, :string
  end
end
