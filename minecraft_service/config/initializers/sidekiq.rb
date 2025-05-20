Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] }

  config.on(:startup) do
    schedule_file = "config/sidekiq.yml"

    if File.exist?(schedule_file)
      config_hash = YAML.load_file(schedule_file)
      schedule = config_hash[:schedule] || config_hash["schedule"]

      Sidekiq::Cron::Job.destroy_all!
      Sidekiq::Cron::Job.load_from_hash!(schedule, source: "schedule")
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] }
end
