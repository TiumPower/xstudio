# Các định dạng ảnh app chấp nhận cho logo và avatar.
#
# SVG nằm trong danh sách nhưng Active Storage KHÔNG dựng được biến thể của nó
# (`variant` ném ActiveStorage::InvariableError) — xem `thumb_source` trong
# ApplicationHelper.
module Attachments
  IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp image/svg+xml image/avif].freeze
end
