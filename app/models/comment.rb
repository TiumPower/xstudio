class Comment < ApplicationRecord
  include Discard::Model

  belongs_to :commentable, polymorphic: true, counter_cache: false
  belongs_to :user

  has_many :mentions, dependent: :destroy
  has_many :mentioned_users, through: :mentions, source: :user
  has_many_attached :files

  validates :body, presence: true

  after_create_commit  :bump_counter
  after_destroy_commit :bump_counter

  scope :chronological, -> { kept.order(:created_at) }

  def edited? = edited_at.present?

  def project
    commentable.is_a?(Project) ? commentable : commentable.try(:project)
  end

  private

  def bump_counter
    return unless commentable.is_a?(Task)
    Task.reset_counters(commentable_id, :comments) if Task.column_names.include?("comments_count")
  rescue StandardError
    commentable.update_column(:comments_count, commentable.comments.kept.count)
  end
end
