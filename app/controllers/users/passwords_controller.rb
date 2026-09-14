class Users::PasswordsController < Devise::PasswordsController
  layout "auth"
  skip_before_action :authenticate_user!, raise: false
end
