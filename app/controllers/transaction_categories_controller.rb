class TransactionCategoriesController < ApplicationController
  before_action :require_admin!

  def create
    category = TransactionCategory.new(category_params)
    category.position = (TransactionCategory.where(kind: category.kind).maximum(:position) || -1) + 1
    if category.save
      redirect_to settings_path, notice: "Đã thêm danh mục #{category.name}."
    else
      redirect_to settings_path, alert: category.errors.full_messages.to_sentence
    end
  end

  def update
    category = TransactionCategory.find(params[:id])
    category.update(category_params)
    redirect_to settings_path, notice: "Đã cập nhật danh mục."
  end

  def destroy
    category = TransactionCategory.find(params[:id])
    category.update(is_active: false) # ẩn thay vì xoá — giữ lịch sử giao dịch
    redirect_to settings_path, notice: "Đã ẩn danh mục #{category.name}."
  end

  private

  def category_params = params.require(:transaction_category).permit(:name, :kind, :is_active, :position)
end
