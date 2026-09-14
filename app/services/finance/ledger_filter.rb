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

      scope = scope.where("transactions.occurred_on >= ?", from) if from
      scope = scope.where("transactions.occurred_on <= ?", to)   if to
      scope = scope.where("transactions.amount >= ?", digits(params[:min_amount])) if params[:min_amount].present?
      scope = scope.where("transactions.amount <= ?", digits(params[:max_amount])) if params[:max_amount].present?
      if params[:q].present?
        scope = scope.where("transactions.description ILIKE :q OR transactions.counterparty ILIKE :q",
                            q: "%#{params[:q].strip}%")
      end
      scope
    end

    def from = @from ||= parse(params[:from]) || Date.current.beginning_of_month
    def to   = @to   ||= parse(params[:to])   || Date.current.end_of_month

    SOURCE_LABELS = { "project" => "Thuộc dự án", "general" => "Chung workspace" }.freeze

    # Chip cho từng điều kiện đang bật, kèm danh sách tham số cần bỏ khi xoá chip.
    def active_chips
      chips = []
      chips << ["Kỳ", "#{I18n.l(from)} – #{I18n.l(to)}", [:from, :to]] unless default_period?
      chips << ["Loại", I18n.t("transaction_kinds.#{params[:kind]}"), [:kind]] if params[:kind].present?
      if (label = SOURCE_LABELS[params[:project_scope]])
        chips << ["Nguồn", label, [:project_scope]]
      end
      if params[:project_id].present?
        project = Project.kept.find_by(id: params[:project_id])
        chips << ["Dự án", project.name, [:project_id]] if project
      end
      if params[:category_id].present?
        name = TransactionCategory.find_by(id: params[:category_id])&.name
        chips << ["Danh mục", name, [:category_id]] if name
      end
      if params[:min_amount].present? || params[:max_amount].present?
        low  = params[:min_amount].presence ? "từ #{params[:min_amount]}" : nil
        high = params[:max_amount].presence ? "đến #{params[:max_amount]}" : nil
        chips << ["Số tiền", [low, high].compact.join(" "), [:min_amount, :max_amount]]
      end
      chips << ["Tìm", params[:q], [:q]] if params[:q].present?
      chips
    end

    # Bao nhiêu điều kiện đang bật — hiện lên nút "Bộ lọc" để không phải mở ra mới biết.
    def active_count = active_chips.size

    def default_period?
      params[:from].blank? && params[:to].blank?
    end

    # Kỳ hiện tại có khớp một mốc nhanh nào không (để tô sáng đúng nút).
    def period_preset
      return "month"   if from == Date.current.beginning_of_month && to == Date.current.end_of_month
      return "quarter" if from == Date.current.beginning_of_quarter && to == Date.current.end_of_quarter
      return "year"    if from == Date.current.beginning_of_year && to == Date.current.end_of_year
      nil
    end

    private

    def parse(v)  = v.present? ? (Date.parse(v) rescue nil) : nil
    def digits(v) = v.to_s.gsub(/[^\d]/, "").to_i
  end
end
