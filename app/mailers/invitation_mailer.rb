class InvitationMailer < ApplicationMailer
  def invite(user_id)
    @user = User.find(user_id)
    return if @user.invitation_token.blank?

    @url = invitation_url(token: @user.invitation_token, host: mail_host)
    mail to: @user.email, subject: "Bạn được mời vào #{@workspace.name}"
  end

  private

  def mail_host = ENV.fetch("APP_HOST", "xstudio.tiumpower.com")
end
