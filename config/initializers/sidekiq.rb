require "sidekiq"

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/2")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  config.on(:startup) do
    schedule_file = Rails.root.join("config/sidekiq.yml")
    next unless File.exist?(schedule_file)

    schedule = YAML.load_file(schedule_file)[:schedule] || YAML.load_file(schedule_file)["schedule"]
    Sidekiq::Cron::Job.load_from_hash!(schedule) if schedule.present? && defined?(Sidekiq::Cron::Job)
  end
end

Sidekiq.configure_client { |config| config.redis = { url: redis_url } }
