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

    # Hàng đợi nền — Sidekiq. Email không bao giờ gửi trong request cycle.
    config.active_job.queue_adapter = :sidekiq

    config.generators do |g|
      g.test_framework nil
      g.helper false
      g.assets false
    end
  end
end
