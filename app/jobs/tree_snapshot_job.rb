# BR-22 — ảnh chụp tự động 23:00, chỉ khi cây có thay đổi trong ngày; giữ 30 bản auto.
class TreeSnapshotJob < ApplicationJob
  queue_as :default

  def perform
    StrategyTree.kept.find_each do |tree|
      changed = tree.strategy_nodes.where("strategy_nodes.updated_at >= ?", Time.zone.now.beginning_of_day).exists?
      next unless changed

      Strategy::Snapshotter.new(tree).capture!(name: "Tự động #{I18n.l(Date.current)}", auto: true)
      extras = tree.strategy_snapshots.automatic.newest.offset(30).pluck(:id)
      tree.strategy_snapshots.where(id: extras).delete_all if extras.any?
    end
  end
end
