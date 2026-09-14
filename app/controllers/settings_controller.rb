class SettingsController < ApplicationController
  before_action :require_admin!, only: [:update]

  def show
    @workspace  = current_workspace
    @income_categories  = TransactionCategory.kind_income.ordered
    @expense_categories = TransactionCategory.kind_expense.ordered
  end

  def update
    if current_workspace.update(workspace_params)
      redirect_to settings_path, notice: "Đã lưu cài đặt."
    else
      redirect_to settings_path, alert: current_workspace.errors.full_messages.to_sentence
    end
  end

  private

  def workspace_params = params.require(:workspace).permit(:name, :tagline, :about, :logo, :timezone)
end
