module Tasks
  # Chuyển một công việc sang dự án khác.
  #
  # Không chỉ đổi `project_id`: cột Kanban, nhãn và mã việc đều gắn với dự án cũ.
  # Bỏ sót một thứ là dữ liệu hỏng âm thầm — thẻ nằm trong cột của dự án khác,
  # hoặc mã việc nói sai nó thuộc dự án nào.
  #
  # Trả về `Result` thay vì ném lỗi: người dùng cần biết những gì bị gỡ bỏ
  # (người thực hiện, nhãn) chứ không chỉ "xong" hay "hỏng".
  class MoveToProject
    Result = Struct.new(:ok, :error, :previous_code, :previous_project,
                        :dropped_assignee, :dropped_labels, keyword_init: true) do
      def ok? = ok
    end

    def initialize(task, project)
      @task = task
      @project = project
    end

    def call
      return failure("Công việc đã hoàn thành thì không chuyển dự án được.") unless @task.movable_to_other_project?
      return failure("Công việc đang ở dự án này rồi.") if @task.project_id == @project.id
      return failure("Dự án đích đã được lưu trữ.") if @project.archived?

      previous_project = @task.project
      previous_code    = @task.code
      dropped_assignee = @task.assignee unless @project.member?(@task.assignee)
      dropped_labels   = @task.labels.where.not(project_id: [nil, @project.id]).to_a

      Task.transaction do
        @task.task_labels.where(label_id: dropped_labels.map(&:id)).destroy_all if dropped_labels.any?
        @task.assignee = nil if dropped_assignee
        @task.board_column = target_column
        @task.position = (@task.board_column&.tasks&.maximum(:position) || 0) + 1024
        @task.project = @project
        @task.code = "#{@project.code}-#{@project.next_task_sequence}"
        @task.save!
      end

      Result.new(ok: true, previous_code: previous_code, previous_project: previous_project,
                 dropped_assignee: dropped_assignee, dropped_labels: dropped_labels)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    # Giữ nguyên chặng đang làm nếu dự án mới có cột cùng khoá ("doing" →
    # "doing"); không có thì về cột đầu. Không bao giờ rơi vào cột hoàn thành —
    # BR-03 sẽ lập tức đánh dấu việc là xong, mà người dùng chỉ muốn chuyển chỗ.
    def target_column
      columns = @project.board_columns.ordered.reject(&:is_done_column?)
      columns.find { |c| c.key == @task.board_column&.key } || columns.first ||
        @project.board_columns.ordered.first
    end

    def failure(message) = Result.new(ok: false, error: message)
  end
end
