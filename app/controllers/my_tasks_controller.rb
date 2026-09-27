# FR-TASK-13 — Việc của tôi: gộp mọi dự án, nhóm theo hạn.
#
# Xem được hai phạm vi: việc của chính mình (mặc định) hoặc việc của cả team.
# Phạm vi "cả team" vẫn bị giới hạn trong những dự án người xem được phép thấy
# (xem `visible_project_ids`), nên thành viên không vì trang này mà nhìn thấy
# việc của dự án mình chưa được thêm vào.
class MyTasksController < ApplicationController
  SCOPES    = %w[mine team].freeze
  GROUP_BYS = %w[due assignee].freeze

  def index
    @scope    = params[:scope].presence_in(SCOPES) || "mine"
    # Xem cả team thì câu hỏi đầu tiên là "ai đang ôm việc gì", nên mặc định
    # nhóm theo người; xem việc của mình thì chỉ có một người, nhóm theo hạn.
    @group_by = @scope == "team" ? (params[:group].presence_in(GROUP_BYS) || "assignee") : "due"

    scope = Task.kept.open_tasks.where(project_id: visible_project_ids)
                .includes(:project, :board_column, :assignee)
                .order(Arel.sql("due_date NULLS LAST"))

    if @scope == "mine"
      scope = scope.where(assignee_id: current_user.id)
    else
      scope = scope.where(project_id: params[:project_id]) if params[:project_id].present?
      case params[:assignee_id]
      when "none"    then scope = scope.where(assignee_id: nil)
      when /\A\d+\z/ then scope = scope.where(assignee_id: params[:assignee_id])
      end
    end

    tasks   = scope.to_a
    @total  = tasks.size
    @groups = @group_by == "assignee" ? assignee_groups(tasks) : due_groups(tasks)

    return if @scope == "mine"

    @projects = visible_projects.order(:name)
    @members  = User.alphabetical
                    .where(id: ProjectMembership.where(project_id: visible_project_ids).select(:user_id))
  end

  private

  # Mỗi nhóm là [nhãn, danh sách việc, người thực hiện] — người thực hiện chỉ
  # có khi nhóm theo người, để view vẽ được avatar ở đầu nhóm.
  def due_groups(tasks)
    today = Date.current
    {
      "Quá hạn"      => tasks.select { |t| t.due_date && t.due_date < today },
      "Hôm nay"      => tasks.select { |t| t.due_date == today },
      "Tuần này"     => tasks.select { |t| t.due_date && t.due_date > today && t.due_date <= today.end_of_week },
      "Sau đó"       => tasks.select { |t| t.due_date && t.due_date > today.end_of_week },
      "Không có hạn" => tasks.select { |t| t.due_date.nil? }
    }.reject { |_, v| v.empty? }.map { |label, list| [ label, list, nil ] }
  end

  # Chưa giao xuống cuối, còn lại xếp theo tên để danh sách không nhảy chỗ.
  def assignee_groups(tasks)
    tasks.group_by(&:assignee)
         .sort_by { |user, _| user ? [ 0, user.display_name.to_s.downcase ] : [ 1, "" ] }
         .map { |user, list| [ user&.display_name || t("common.unassigned"), list, user ] }
  end
end
