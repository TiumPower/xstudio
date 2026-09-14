lock "~> 3.18"

set :application, "xstudio"
# Repo bare trên chính server (giống Bơi Đạt). Đổi sang GitHub bằng
# REPO_URL=git@github.com:vietlee/xstudio.git cap production deploy
set :repo_url,    ENV.fetch("REPO_URL", "/home/deploy/repos/xstudio.git")

set :deploy_to,   "/var/www/xstudio"
set :branch,      ENV.fetch("BRANCH", "main")

# rbenv
set :rbenv_type,   :user
set :rbenv_ruby,   File.read(".ruby-version").strip.sub(/^ruby-/, "")
set :rbenv_prefix, "RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=#{fetch(:rbenv_ruby)} $HOME/.rbenv/bin/rbenv exec"
set :rbenv_path,   "$HOME/.rbenv"

# Giữ lại qua các lần deploy
set :linked_files, %w[.env]
set :linked_dirs, %w[
  log
  tmp/pids
  tmp/cache
  tmp/sockets
  storage
  public/assets
]

set :keep_releases, 5
set :assets_roles, [:web]

# Puma
set :puma_threads,        [2, 4]
set :puma_workers,        2
set :puma_bind,           "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state,          "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,            "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log,     "#{release_path}/log/puma.access.log"
set :puma_error_log,      "#{release_path}/log/puma.error.log"
set :puma_preload_app,    true
set :puma_init_active_record, true

# Sidekiq (systemd, unit tên sidekiq-xstudio)
set :sidekiq_config, "#{current_path}/config/sidekiq.yml"

namespace :deploy do
  desc "Nạp dữ liệu mẫu (chạy tay: cap production deploy:seed)"
  task :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:seed"
        end
      end
    end
  end

  after :publishing, :restart

  after :finishing, :restart_sidekiq do
    on roles(:app) do
      execute :sudo, "systemctl restart sidekiq-xstudio"
    end
  end

  # Script sao lưu nằm trong shared/ chứ không trong release: một bản deploy
  # hỏng (hoặc rollback) không được phép làm dừng sao lưu.
  desc "Cài script sao lưu hằng đêm và mục cron của nó"
  task :install_backup do
    on roles(:db) do
      dest = "#{shared_path}/bin/xstudio_backup.sh"
      execute :mkdir, "-p", "#{shared_path}/bin"
      upload! "bin/xstudio_backup.sh", dest
      execute :chmod, "+x", dest
      line = "15 3 * * * #{dest} >> #{shared_path}/log/backup.log 2>&1"
      execute %(crontab -l 2>/dev/null | grep -v 'xstudio_backup.sh' > /tmp/xstudio_cron || true)
      execute %(echo "#{line}" >> /tmp/xstudio_cron && crontab /tmp/xstudio_cron && rm -f /tmp/xstudio_cron)
    end
  end
  after :finishing, :install_backup
end
