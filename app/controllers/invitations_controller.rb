# Kích hoạt lời mời — người được mời đặt mật khẩu và họ tên (FR-AUTH-02/03).
class InvitationsController < ApplicationController
  layout "auth"
  skip_before_action :authenticate_user!
  before_action :load_invitee

  def show
  end

  def update
    if @user.accept_invitation!(invite_params)
      sign_in(@user)
      redirect_to root_path, notice: "Chào mừng #{@user.full_name}! Tài khoản đã kích hoạt."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_invitee
    @user = User.find_by(invitation_token: params[:token])
    return if @user&.invitation_valid?

    redirect_to new_user_session_path,
                alert: "Liên kết mời không còn hiệu lực. Hãy đề nghị quản trị viên gửi lại."
  end

  def invite_params
    params.require(:user).permit(:full_name, :job_title, :phone, :password, :password_confirmation)
  end
end
