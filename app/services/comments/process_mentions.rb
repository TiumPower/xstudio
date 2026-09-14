module Comments
  # Nhận diện @mention trong nội dung bình luận (FR-CMT-03).
  # Cú pháp: @[Tên người](id) do trình soạn thảo chèn, hoặc @tên-viết-liền.
  class ProcessMentions
    PATTERN = /@\[(?<name>[^\]]+)\]\((?<id>\d+)\)/

    def initialize(comment, actor:)
      @comment = comment
      @actor   = actor
    end

    def call
      ids = @comment.body.to_s.scan(PATTERN).map { |(_, id)| id.to_i }.uniq
      ids &= User.where(status: User.statuses[:active]).pluck(:id)
      return [] if ids.empty?

      new_ids = ids - @comment.mentions.pluck(:user_id)
      new_ids.each do |uid|
        mention = @comment.mentions.create(user_id: uid, notified_at: Time.current)
        next unless mention.persisted?
        Notifications::Dispatch.mentioned(@comment, User.find(uid), actor: @actor)
      end
      new_ids
    end
  end
end
