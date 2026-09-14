module Finance
  # Bộ lọc sổ thu chi (FR-FIN-06) — dùng chung cho bảng và cho xuất Excel/CSV.
  class LedgerFilter
    ATTRS = %i[kind project_scope project_id category_id created_by_id from to
               min_amount max_amount q].freeze
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def apply(scope)
      scope = scope.where(kind: params[:kind])              if params[:kind].present?
      scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
      scope = scope.where(created_by_id: params[:created_by_id]) if params[:created_by_id].present?

      case params[:project_scope]
      when "project" then scope = scope.where.not(project_id: nil)
      when "general" then scope = scope.general
      end
      scope = scope.where(project_id: params[:project_id])  if params[:project_id].present?

      scope = scope.where("occurred_on >= ?", from) if from
      scope = scope.where("occurred_on <= ?", to)   if to
      scope = scope.where("amount >= ?", digits(params[:min_amount])) if params[:min_amount].present?
      scope = scope.where("amount <= ?", digits(params[:max_amount])) if params[:max_amount].present?
      if params[:q].present?
        scope = scope.where("description ILIKE :q OR counterparty ILIKE :q", q: "%#{params[:q].strip}%")
      end
      scope
    end

    def from = @from ||= parse(params[:from]) || Date.current.beginning_of_month
    def to   = @to   ||= parse(params[:to])   || Date.current.end_of_month

    def active_chips
      chips = []
      chips << ["Kỳ", "#{I18n.l(from)} – #{I18n.l(to)}", [:from, :to]]
      chips << ["Loại", I18n.t("transaction_kinds.#{params[:kind]}"), [:kind]] if params[:kind].present?
      if params[:project_id].present?
        name = Project.kept.find_by(id: params[:project_id])&.name
        chips << ["Dự án", name, [:project_id]] if name
      end
      if params[:category_id].present?
        name = TransactionCategory.find_by(id: params[:category_id])&.name
        chips << ["Danh mục", name, [:category_id]] if name
      end
      chips << ["Tìm", params[:q], [:q]] if params[:q].present?
      chips
    end

    private

    def parse(v)  = v.present? ? (Date.parse(v) rescue nil) : nil
    def digits(v) = v.to_s.gsub(/[^\d]/, "").to_i
  end
end
