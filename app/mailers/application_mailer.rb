class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Team Workspace <no-reply@xstudio.czin.net>") }
  layout "mailer"

  helper :application

  before_action { @workspace = Workspace.current }
end
