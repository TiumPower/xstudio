# Cấu hình Puma — production chạy qua systemd user unit, nginx nói chuyện
# bằng unix socket trong shared/tmp/sockets.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 4).to_i
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }.to_i
threads min_threads_count, max_threads_count

rails_env = ENV.fetch("RAILS_ENV", "development")
environment rails_env

if rails_env == "production"
  app_dir = "/var/www/xstudio"
  bind "unix://#{app_dir}/shared/tmp/sockets/puma.sock"
  pidfile   "#{app_dir}/shared/tmp/pids/puma.pid"
  state_path "#{app_dir}/shared/tmp/pids/puma.state"

  workers ENV.fetch("WEB_CONCURRENCY", 2).to_i
  preload_app!
  on_worker_boot { ActiveRecord::Base.establish_connection if defined?(ActiveRecord) }
else
  port ENV.fetch("PORT", 3012)
  worker_timeout 3600
  plugin :tmp_restart
end
