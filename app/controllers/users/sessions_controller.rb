class Users::SessionsController < Devise::SessionsController
  layout "auth"
  before_action :configure_permitted_parameters
  skip_before_action :authenticate_user!, raise: false

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:remember_me])
  end
end
