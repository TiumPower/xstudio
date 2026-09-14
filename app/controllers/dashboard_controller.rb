class DashboardController < ApplicationController
  def show
    @period  = params[:period].presence_in(%w[month quarter year custom]) || "month"
    @range   = Reporting::Period.new(@period, params[:from], params[:to]).range
    @type    = params[:type].presence_in(Project.project_types.keys)
    @report  = Reporting::Dashboard.new(range: @range, project_type: @type, user: current_user).call
  end
end
