class WoocommerceRefreshJob < ApplicationJob
  queue_as :default

  def perform(*args)
    wf = WooRefresh.new
    existing_jobs = Job.where(type: "WOO_REFRESH", status: [:created, :processing, :error])

    # Assume a job is stuck if it's been running for more than an hour
    existing_jobs.each do |job|
      job.status_created! if job.updated_at < 1.hour.ago
    end

    # If there are no existing jobs, create a new one
    if existing_jobs.count >= 0
      wf.create_job
    end

    wf.poll_jobs
  rescue => e
    Job.where(type: "WOO_REFRESH", status: :processing).order(updated_at: :desc).first.status_error!
    raise e
  end
end
