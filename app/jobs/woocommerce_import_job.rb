class WoocommerceImportJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executed

  def perform(*args)
    WooImport.new.poll_jobs
  rescue => e
    Job.where(type: "WOO_IMPORT", status: :processing).each do |job|
      job.status_error!
    end
    WoocommerceImportJob.set(wait: 5.minutes).perform_later
    raise e
  end
end
