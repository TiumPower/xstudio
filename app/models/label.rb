class Label < ApplicationRecord
  belongs_to :project, optional: true
  has_many :task_labels, dependent: :destroy
  has_many :tasks, through: :task_labels

  validates :name, presence: true, uniqueness: { scope: :project_id, case_sensitive: false }
end
