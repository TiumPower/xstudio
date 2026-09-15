# FR-TASK-13 — Việc của tôi: gộp mọi dự án, nhóm theo hạn.
class MyTasksController < ApplicationController
  def index
    scope = Task.kept.open_tasks.where(assignee_id: current_user.id)
                .where(project_id: visible_project_ids)
                .includes(:project, :board_column).order(Arel.sql("due_date NULLS LAST"))

    today = Date.current
    @groups = {
      "Quá hạn"     => scope.select { |t| t.due_date && t.due_date < today },
      "Hôm nay"     => scope.select { |t| t.due_date == today },
      "Tuần này"    => scope.select { |t| t.due_date && t.due_date > today && t.due_date <= today.end_of_week },
      "Sau đó"      => scope.select { |t| t.due_date && t.due_date > today.end_of_week },
      "Không có hạn" => scope.select { |t| t.due_date.nil? }
    }.reject { |_, v| v.empty? }
    @total = scope.size
  end
end
