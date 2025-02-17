class CleanJobsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    cj = CleanJobs.new
    cj.create_job
    cj.poll_jobs
  rescue => e
    Job.where(type: "CLEAN_JOBS", status: :processing).order(updated_at: :desc).first.status_error!
    raise e
  end
end
