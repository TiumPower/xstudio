# Bucket `czin` trên DigitalOcean Spaces dùng chung cho nhiều app. Nếu mọi tệp
# đổ thẳng ra gốc bucket thì không còn cách nào nhìn ra tệp nào của app nào —
# lúc dọn dẹp hay tính dung lượng sẽ rất khổ. Nên gắn tiền tố cho khoá.
#
# Chỉ áp dụng cho blob MỚI: `self[:key]` đã có (tệp cũ, hoặc tệp lưu trên đĩa)
# thì giữ nguyên, không đụng tới.
ActiveSupport.on_load(:active_storage_blob) do
  prefix = ENV["STORAGE_KEY_PREFIX"].presence || "xstudio"

  define_method(:key) do
    self[:key] ||= "#{prefix}/#{self.class.generate_unique_secure_token(length: ActiveStorage::Blob::MINIMUM_TOKEN_LENGTH)}"
  end
end
