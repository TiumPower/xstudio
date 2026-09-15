class TransactionsController < ApplicationController
  before_action :load_transaction, only: [:show, :edit, :update, :destroy]

  def index
    @filter  = Finance::LedgerFilter.new(params)
    @scope   = @filter.apply(Transaction.kept.includes(:category, :project, :created_by))
    @totals  = { income: @scope.income.sum(:amount), expense: @scope.expense.sum(:amount) }
    @totals[:balance] = @totals[:income] - @totals[:expense]
    @split = {
      project_income:  @scope.income.where.not(project_id: nil).sum(:amount),
      project_expense: @scope.expense.where.not(project_id: nil).sum(:amount),
      general_income:  @scope.income.general.sum(:amount),
      general_expense: @scope.expense.general.sum(:amount)
    }
    @pagy         = Pagination.new(@scope.newest, page: params[:page])
    @transactions = @pagy.records
    @categories   = TransactionCategory.active.ordered
    @projects     = Project.kept.order(:name)
  end

  def export
    @filter = Finance::LedgerFilter.new(params)
    @transactions = @filter.apply(Transaction.kept.includes(:category, :project, :created_by)).newest
    respond_to do |format|
      format.xlsx do
        response.headers["Content-Disposition"] =
          "attachment; filename=\"so-thu-chi-#{Date.current.strftime('%d-%m-%Y')}.xlsx\""
      end
      format.csv do
        send_data Finance::CsvExport.new(@transactions).call,
                  filename: "so-thu-chi-#{Date.current.strftime('%d-%m-%Y')}.csv",
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  def new
    @transaction = Transaction.new(kind: params[:kind].presence || "expense",
                                   occurred_on: Date.current,
                                   project_id: params[:project_id])
    load_form_data
  end

  def create
    @transaction = Transaction.new(transaction_params)
    @transaction.created_by = current_user

    if @transaction.save
      log_activity("created", trackable: @transaction, project: @transaction.project,
                   summary: "đã ghi #{@transaction.kind_label.downcase} #{helpers.format_vnd(@transaction.amount)}")
      close_modal_or_redirect("Đã ghi giao dịch.")
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def show = redirect_to edit_transaction_path(@transaction)

  def edit
    load_form_data
  end

  def update
    authorize_creator!
    if @transaction.update(transaction_params)
      log_activity("updated", trackable: @transaction, project: @transaction.project,
                   summary: "đã sửa giao dịch #{helpers.format_vnd(@transaction.amount)}")
      close_modal_or_redirect("Đã lưu giao dịch.")
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_creator!
    @transaction.discard
    log_activity("deleted", trackable: @transaction, project: @transaction.project,
                 summary: "đã xoá giao dịch #{helpers.format_vnd(@transaction.amount)}")
    redirect_to transactions_path, notice: "Đã xoá giao dịch."
  end

  private

  # Form mở trong popup thì đóng popup rồi nạp lại trang đang đứng — người dùng
  # không bị văng khỏi dự án đang xem. Mở ở trang riêng thì điều hướng như cũ.
  def close_modal_or_redirect(notice)
    flash[:notice] = notice
    if turbo_frame_request?
      back = params[:return_to].presence || request.referer.presence || transactions_path
      render turbo_stream: [turbo_stream.update("modal", ""),
                            turbo_stream.action(:redirect, back)]
    else
      redirect_to(params[:return_to].presence || transactions_path)
    end
  end

  def load_transaction = @transaction = Transaction.kept.find(params[:id])

  def load_form_data
    @categories = TransactionCategory.active.ordered
    @projects   = Project.active.order(:name)
  end

  def transaction_params
    permitted = params.require(:transaction).permit(:kind, :amount, :occurred_on, :category_id,
                                                    :project_id, :description, :counterparty,
                                                    :payment_method, receipts: [])
    permitted[:amount] = permitted[:amount].to_s.gsub(/[^\d]/, "") if permitted[:amount].present?
    permitted
  end

  # FR-FIN-10 — chỉ người tạo hoặc Admin.
  def authorize_creator!
    return if current_user.role_admin? || @transaction.created_by_id == current_user.id
    raise Pundit::NotAuthorizedError
  end
end
