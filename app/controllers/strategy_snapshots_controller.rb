class StrategySnapshotsController < ApplicationController
  before_action :load_tree

  def index
    @pagy      = Pagination.new(@tree.strategy_snapshots.newest.includes(:created_by), page: params[:page])
    @snapshots = @pagy.records
  end

  def create
    name = params[:name].presence || "Phiên bản #{I18n.l(Time.current, format: :default)}"
    Strategy::Snapshotter.new(@tree).capture!(name: name, actor: current_user)
    redirect_to strategy_tree_strategy_snapshots_path(@tree), notice: "Đã lưu ảnh chụp “#{name}”."
  end

  def restore
    snapshot = @tree.strategy_snapshots.find(params[:id])
    Strategy::Snapshotter.new(@tree).restore!(snapshot, actor: current_user)
    log_activity("updated", trackable: @tree, summary: "đã khôi phục cây #{@tree.name} về “#{snapshot.name}”")
    redirect_to strategy_tree_path(@tree), notice: "Đã khôi phục về “#{snapshot.name}”. Trạng thái trước đó đã được chụp lại."
  end

  def destroy
    @tree.strategy_snapshots.find(params[:id]).destroy
    redirect_to strategy_tree_strategy_snapshots_path(@tree), notice: "Đã xoá ảnh chụp."
  end

  private

  def load_tree = @tree = StrategyTree.kept.find_by!(slug: params[:strategy_tree_slug])
end
