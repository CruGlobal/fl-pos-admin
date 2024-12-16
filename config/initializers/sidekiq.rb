require 'datadog/statsd'

redis_conf = YAML.safe_load(ERB.new(File.read(Rails.root.join("config", "redis.yml"))).result, permitted_classes: [Symbol], aliases: true)["sidekiq"]

redis_settings = {url: Redis.new(redis_conf).id}

SidekiqUniqueJobs.configure do |config|
  # don't use SidekiqUniqueJobs in test env because it will cause head-scratching
  # https://github.com/mhenrixon/sidekiq-unique-jobs#uniqueness
  # https://github.com/mperham/sidekiq/wiki/Ent-Unique-Jobs#enable (not our gem but Sidekiq Enterprise suggested the same thing)
  config.enabled = !Rails.env.test?
end

Sidekiq.configure_client do |config|
  config.redis = redis_settings

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end

Sidekiq::Client.reliable_push! if Sidekiq::Client.method_defined? :reliable_push!

Sidekiq.configure_server do |config|
  config.super_fetch!
  config.reliable_scheduler!
  config.redis = redis_settings
  config.logger = Sidekiq::Logger.new($stdout) unless Rails.env.test? # we don't need a logger in test env

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  SidekiqUniqueJobs::Server.configure(config)
end

Sidekiq.default_job_options = {
  backtrace: true,
  # Set uniqueness lock expiration to 24 hours to balance preventing
  # duplicate jobs from running (if uniqueness time is too short) and donor
  # import / email jobs not getting queued because the locks don't
  # always get cleared properly (perhaps on new deploys/out of memory
  # errors).
  lock_expiration: 24.hours
}

if ENV["AWS_EXECUTION_ENV"].present?
  Sidekiq::Pro.dogstatsd = -> { Datadog::Statsd.new socket_path: "/var/run/datadog/dsd.socket" }
end
