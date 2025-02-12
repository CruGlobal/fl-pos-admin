class WoocommerceImportJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: true

  def perform(*args)
    WooImport.new.poll_jobs
  rescue => e
    WooImport.where(type: "WOO_IMPORT", status: :processing).order(updated_at: :desc).first.status_error!
    raise e
  end
end
