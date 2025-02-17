class LightspeedExtractJob < ApplicationJob
  queue_as :default

  def perform(*args)
    LSExtract.new.poll_jobs
  rescue => e
    Job.where(type: "LS_EXTRACT", status: :processing).order(updated_at: :desc).first.status_error!
    raise e
  end
end
