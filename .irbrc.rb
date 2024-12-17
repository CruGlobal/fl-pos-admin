require "pry"
Pry.config.prompt = [
  proc do
    current_app = ENV["MARCO_POLO_APP_NAME"] || Rails.application.class.module_parent_name.underscore.tr("_", "-")
    rails_env = Rails.env.downcase

    # shorten some common long environment names
    rails_env = "dev" if rails_env == "development"
    rails_env = "prod" if rails_env == "production"

    "#{current_app}-pry(#{rails_env})> "
  end,
  proc { "> " }
]
Pry.start
exit
