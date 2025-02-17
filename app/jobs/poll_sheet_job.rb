class PollSheetJob < ApplicationJob
  queue_as :default

  def perform(*args)
    ps = PollSheet.new
    ps.create_job
    ps.poll_jobs
  rescue => e
    Job.where(type: "POLL_SHEET", status: :processing).order(updated_at: :desc).first.status_error!
    raise e
  end
end
