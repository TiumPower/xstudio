module Notifications
  # Một chỗ duy nhất tạo thông báo trong app + xếp email vào hàng đợi nền.
  # BR-12 — không bao giờ báo cho chính người vừa gây ra hành động.
  module Dispatch
    module_function

    def task_assigned(task, actor:)
      user = task.assignee
      return if user.blank? || user.id == actor&.id
      push(user, "task_assigned", actor: actor,
           title: "Bạn được giao: #{task.title}",
           body:  "#{task.project.code} · #{task.code}",
           url:   Rails.application.routes.url_helpers.task_path(task))
    end

    def added_to_project(project, users, actor:)
      Array(users).uniq.each do |user|
        next if user.id == actor&.id
        push(user, "added_to_project", actor: actor,
             title: "Bạn được thêm vào dự án #{project.name}",
             body:  project.code,
             url:   Rails.application.routes.url_helpers.project_path(project))
      end
    end

    def mentioned(comment, user, actor:)
      return if user.id == actor&.id
      push(user, "mentioned", actor: actor,
           title: "#{actor&.display_name} đã nhắc tên bạn",
           body:  ActionController::Base.helpers.strip_tags(comment.body).truncate(120),
           url:   comment_url_for(comment))
    end

    def comment_added(comment, actor:)
      recipients(comment).each do |user|
        next if user.id == actor&.id
        next if comment.mentioned_users.exists?(id: user.id) # đã báo ở mention rồi
        push(user, "comment_added", actor: actor,
             title: "Bình luận mới trên #{comment_target_label(comment)}",
             body:  ActionController::Base.helpers.strip_tags(comment.body).truncate(120),
             url:   comment_url_for(comment))
      end
    end

    def task_status_changed(task, actor:)
      user = task.assignee
      return if user.blank? || user.id == actor&.id
      push(user, "task_status_changed", actor: actor,
           title: "#{task.code} đã chuyển sang #{task.board_column&.name}",
           body:  task.title,
           url:   Rails.application.routes.url_helpers.task_path(task))
    end

    def project_status_changed(project, actor:)
      user = project.owner
      return if user.blank? || user.id == actor&.id
      push(user, "project_status_changed", actor: actor,
           title: "Dự án #{project.name} → #{I18n.t("project_statuses.#{project.status}")}",
           body:  project.code,
           url:   Rails.application.routes.url_helpers.project_path(project))
    end

    def task_due_soon(task)
      return if task.assignee.blank?
      push(task.assignee, "task_due_soon", actor: nil,
           title: "Sắp đến hạn: #{task.title}",
           body:  "Hạn #{I18n.l(task.due_date)} · #{task.code}",
           url:   Rails.application.routes.url_helpers.task_path(task))
    end

    def task_overdue(task)
      return if task.assignee.blank?
      push(task.assignee, "task_overdue", actor: nil,
           title: "Quá hạn: #{task.title}",
           body:  "Hạn #{I18n.l(task.due_date)} · #{task.code}",
           url:   Rails.application.routes.url_helpers.task_path(task))
    end

    # ---- nội bộ ----------------------------------------------------------
    def push(user, event_type, title:, body: nil, url: nil, actor: nil)
      return unless user.status_active? || event_type == "invited_to_workspace"

      setting = user.notification_settings.find_by(event_type: event_type)
      return if setting && !setting.in_app_enabled && !setting.email_enabled

      notification = Notification.create!(user: user, event_type: event_type, title: title,
                                          body: body, url: url, actor: actor, created_at: Time.current)
      NotificationMailer.event(notification.id).deliver_later if user.email_enabled_for?(event_type)
      notification
    rescue StandardError => e
      Rails.logger.warn("[Notifications] #{event_type} thất bại: #{e.message}")
      nil
    end

    def recipients(comment)
      target = comment.commentable
      users  = if target.is_a?(Task)
                 [target.assignee, target.reporter] + target.comments.kept.map(&:user)
               else
                 [target.owner] + target.comments.kept.map(&:user)
               end
      users.compact.uniq
    end

    def comment_url_for(comment)
      h = Rails.application.routes.url_helpers
      comment.commentable.is_a?(Task) ? h.task_path(comment.commentable) : h.project_path(comment.commentable)
    end

    def comment_target_label(comment)
      comment.commentable.is_a?(Task) ? "công việc #{comment.commentable.code}" : "dự án #{comment.commentable.name}"
    end
  end
end
