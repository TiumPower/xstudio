require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Xstudio
  class Application < Rails::Application
    config.load_defaults 7.2

    config.autoload_lib(ignore: %w[assets tasks])

    # Giờ Việt Nam ở mọi nơi; DB vẫn lưu UTC.
    config.time_zone = "Asia/Ho_Chi_Minh"
    config.active_record.default_timezone = :utc

    # Toàn bộ giao diện tiếng Việt — không có ngôn ngữ thứ hai ở bản này.
    config.i18n.default_locale = :vi
    config.i18n.available_locales = [:vi]
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]

    # SVG: Active Storage mặc định phát dạng nhị phân (buộc tải về) vì SVG có
    # thể chứa script — mở thẳng đường dẫn tệp là script chạy trên chính tên
    # miền app. Ở bản chạy thật, tệp nằm trên DigitalOcean Spaces và đường dẫn
    # tải về là tên miền của Spaces, khác hẳn tên miền app, nên script trong
    # SVG (nếu có) không chạm được vào phiên đăng nhập. Không cho hiện thẳng
    # thì logo hay avatar dạng SVG chỉ ra ô ảnh vỡ.
    config.active_storage.content_types_to_serve_as_binary -= ["image/svg+xml"]
    config.active_storage.content_types_allowed_inline     += ["image/svg+xml"]

    # Hàng đợi nền — Sidekiq. Email không bao giờ gửi trong request cycle.
    config.active_job.queue_adapter = :sidekiq

    config.generators do |g|
      g.test_framework nil
      g.helper false
      g.assets false
    end
  end
end
