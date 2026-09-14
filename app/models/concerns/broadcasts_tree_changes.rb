# FR-TREE-41 — thay đổi của người này hiện sang người khác trong vài giây.
#
# Canvas cây được Stimulus vẽ từ một payload JSON duy nhất, nên thay vì
# broadcast HTML từng nút, ta phát một "sự kiện" nhỏ vào luồng Turbo của cây.
# Trình duyệt nhận được sẽ tự tải lại cây — trừ chính người vừa gây ra thay đổi.
module BroadcastsTreeChanges
  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_tree_change, on: [:create, :update, :destroy]
  end

  # Người đang thao tác, đặt từ controller để không tự báo cho chính mình (BR-12).
  attr_accessor :broadcast_actor_id

  private

  def broadcast_tree_change
    tree = strategy_tree
    return if tree.blank?

    Turbo::StreamsChannel.broadcast_append_to(
      [tree, :events],
      target: "tree_events",
      partial: "strategy_trees/event",
      locals: {
        node_id:   id,
        node_title: title,
        actor_id:  broadcast_actor_id || updated_by_id,
        actor_name: (User.find_by(id: broadcast_actor_id || updated_by_id)&.display_name),
        at: Time.current.to_i
      }
    )
  rescue StandardError => e
    Rails.logger.warn("[Tree broadcast] #{e.message}")
  end
end
