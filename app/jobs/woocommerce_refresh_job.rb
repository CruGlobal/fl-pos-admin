class WoocommerceRefreshJob < ApplicationJob
  queue_as :default

  def perform(*args)
    wf = WooRefresh.new
    wf.create_job
    wf.poll_jobs
  rescue => e
    Job.where(type: "WOO_REFRESH", status: :processing).order(updated_at: :desc).first.status_error!
    raise e
  end
end
