class SalesforceImportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    SFImport.new.poll_jobs
  rescue => e
    Job.where(type: "SF_IMPORT", status: :processing).order(updated_at: :desc).first.status_error!
    raise e
  end
end
