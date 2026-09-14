class ProfileController < ApplicationController
  def show
    @settings = Notification::EVENT_TYPES.index_with { |et| current_user.notification_setting_for(et) }
  end

  def update
    if current_user.update(profile_params)
      redirect_to profile_path, notice: "Đã lưu hồ sơ."
    else
      redirect_to profile_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  def password
    unless current_user.valid_password?(params[:current_password].to_s)
      redirect_to profile_path, alert: "Mật khẩu hiện tại không đúng."
      return
    end
    if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      bypass_sign_in(current_user)
      redirect_to profile_path, notice: "Đã đổi mật khẩu."
    else
      redirect_to profile_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  def notifications
    current_user.update(daily_digest_enabled: params[:daily_digest_enabled] == "1")
    Notification::EVENT_TYPES.each do |event_type|
      setting = current_user.notification_setting_for(event_type)
      setting.email_enabled  = params.dig(:email, event_type) == "1"
      setting.in_app_enabled = params.dig(:in_app, event_type) != "0"
      setting.save!
    end
    redirect_to profile_path, notice: "Đã lưu cấu hình thông báo."
  end

  private

  def profile_params = params.require(:user).permit(:full_name, :job_title, :phone, :avatar)
end
