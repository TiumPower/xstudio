# Phân trang tối giản — app chỉ có vài người dùng nên không cần kéo thêm gem.
# Dùng: @page = Pagination.new(scope, page: params[:page]); @page.records
class Pagination
  PER_PAGE = 20
  WINDOW   = 2 # số trang hiện hai bên trang hiện tại

  attr_reader :per_page

  def initialize(scope, page:, per_page: PER_PAGE)
    @scope    = scope
    @per_page = per_page.to_i.clamp(1, 200)
    @page     = [page.to_i, 1].max
  end

  def total_count
    @total_count ||= @scope.except(:order, :limit, :offset).count
  end

  def total_pages
    @total_pages ||= [(total_count / per_page.to_f).ceil, 1].max
  end

  # Nhảy tay vào ?page=999 thì trả về trang cuối thay vì bảng trống.
  def current_page = @current_page ||= @page.clamp(1, total_pages)

  def offset  = (current_page - 1) * per_page
  def records = @records ||= @scope.limit(per_page).offset(offset).to_a

  def first? = current_page == 1
  def last?  = current_page >= total_pages
  def many?  = total_pages > 1

  def prev_page = first? ? nil : current_page - 1
  def next_page = last?  ? nil : current_page + 1

  def from = total_count.zero? ? 0 : offset + 1
  def to   = [offset + per_page, total_count].min

  # Dãy số trang có rút gọn: 1 … 4 5 [6] 7 8 … 20
  def page_numbers
    return (1..total_pages).to_a if total_pages <= 7

    pages = [1, total_pages]
    ((current_page - WINDOW)..(current_page + WINDOW)).each { |n| pages << n if n.between?(1, total_pages) }
    pages = pages.uniq.sort

    pages.each_with_object([]) do |n, out|
      out << :gap if out.any? && n - out.last.to_i > 1
      out << n
    end
  end
end
