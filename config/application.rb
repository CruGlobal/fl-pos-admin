require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/log/logger"
require_relative "../lib/bootstrap_pagination_renderer"

module FlPosAdmin
  # Load-balancer health-check endpoint. Single source of truth: these configs
  # reference the constants and stay in sync automatically:
  #   - config/environments/production.rb   (ssl_options redirect exclude)
  #   - config/environments/production.rb   (silence_healthcheck_path)
  #   - config/environments/production.rb   (host_authorization exclude)
  #   - config/initializers/lograge.rb      (ignore_actions, which needs the controller#action form)
  #   - config/initializers/datadog_trace.rb (span filter that drops health-check traces)
  # Intentionally still hardcoded -- a rename must update these by hand:
  #   - config/routes.rb                    (route definition, which needs the path without its leading slash)
  #   - cru-terraform: the ALB target-group health-check path
  HEALTHCHECK_PATH = "/monitors/lb"
  HEALTHCHECK_ACTION = "MonitorsController#lb"

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Send all logs to stdout, which docker reads and sends to datadog.
    config.logger = Log::Logger.new($stdout) unless Rails.env.test? # we don't need a logger in test env
  end
end
