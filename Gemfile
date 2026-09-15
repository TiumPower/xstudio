source "https://rubygems.org"

gem "rails", "~> 7.2.3", ">= 7.2.3.2"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
# ActionCable (Rails 7.2) khai báo redis (>= 4, < 6); redis 6 làm adapter
# pubsub không nạp được và mọi broadcast im lặng thất bại.
gem "redis", "~> 5.4"
gem "rack-attack"
gem "connection_pool", "~> 2.4"

# --- Xstudio / Team Workspace stack (mirrors Loyalty / Estate) ---
# Authentication & authorization
gem "devise"
gem "devise-i18n"
gem "pundit"

# Slugs (project codes stay first-class columns; friendly_id for trees)
gem "friendly_id", "~> 5.5"

# Background jobs
gem "sidekiq"
gem "sidekiq-cron"

# AI — Anthropic Claude API (gợi ý nhánh cây định hướng)
gem "faraday"
gem "faraday-retry"

# Charts (Tổng quan)
gem "chartkick"
gem "groupdate"

# Rich text (mô tả công việc, bình luận)
# ActionText ships with Rails; Trix comes from the actiontext gem install.

# Soft delete
gem "discard", "~> 2.0"

# Xuất Excel sổ thu chi
gem "caxlsx"
gem "caxlsx_rails"

# File uploads / image variants
gem "image_processing", "~> 1.2"

# Env management
gem "dotenv-rails"

# Demo/seed data
gem "faker"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Error monitoring — inert until SENTRY_DSN is set.
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "factory_bot_rails"

  # Deployment (Capistrano, mirrors Loyalty / Estate)
  gem "capistrano",         "~> 3.18", require: false
  gem "capistrano-rails",   "~> 1.6",  require: false
  gem "capistrano-rbenv",   "~> 2.2",  require: false
  gem "capistrano3-puma",   "~> 6.0",  require: false
  gem "capistrano-sidekiq", "~> 2.3",  require: false
end

group :development do
  gem "web-console"
  gem "letter_opener"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

# Rails 7.2 gọi JSON.generate(quirks_mode:) — json 3.x đã bỏ keyword này.
gem "json", "~> 2.21"

# DigitalOcean Spaces dùng giao thức tương thích S3.
gem "aws-sdk-s3", require: false
