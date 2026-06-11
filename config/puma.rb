# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Keep sidekiq-cron polling alive in the always-on web process.
#
# sidekiq-cron starts its poller only inside Sidekiq *workers* — it patches the
# Sidekiq server Launcher from within a Sidekiq.configure_server block, which
# never runs in Puma. But sidekiq-foreman scales the Sidekiq worker fleet to
# desiredCount=0 when the queues are idle, and with zero workers there is no
# poller, so cron jobs silently stop enqueuing and never fire.
#
# Running a poller here, in the always-on web container, keeps cron jobs
# enqueuing regardless of worker count; once a job lands in a queue the foreman
# scales workers back up to run it. Safe to run alongside the workers' own
# poller: sidekiq-cron gates each occurrence on an atomic Redis ZADD, so no job
# is enqueued twice. Background: CruGlobal/sidekiq-foreman docs/sidekiq-cron-web-poller.md
#
# NOTE: Puma runs in single mode here (no `workers` directive). If clustering is
# ever enabled (WEB_CONCURRENCY), move this to `on_worker_boot` so the poller
# starts in each forked worker rather than the master.
on_booted do
  unless Rails.env.development? || Rails.env.test?
    begin
      require "sidekiq/cron"
      # Mirror sidekiq-cron's server Launcher: copy the poll interval onto the
      # config the poller reads (Poller#poll_interval_average returns
      # config[:cron_poll_interval] with no fallback).
      config = Sidekiq.default_configuration
      config[:cron_poll_interval] = Sidekiq::Cron.configuration.cron_poll_interval.to_i
      Sidekiq::Cron::Poller.new(config).start
      Rails.logger.info("[sidekiq-cron] poller started in web process (foreman scale-to-zero mitigation)")
    rescue => e
      Rails.logger.error("[sidekiq-cron] failed to start web poller: #{e.class}: #{e.message}")
    end
  end
end
