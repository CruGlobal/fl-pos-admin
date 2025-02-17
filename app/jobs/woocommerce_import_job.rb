class WoocommerceImportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    WooImport.new.poll_jobs
  rescue => e
    Job.where(type: "WOO_IMPORT", status: :processing).order(updated_at: :desc).first.status_error!
    raise e
  end
end
