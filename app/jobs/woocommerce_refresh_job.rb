class WoocommerceRefreshJob < ApplicationJob
  queue_as :default

  def perform(*args)
    wf = WooRefresh.new
    wf.create_job
    wf.poll_jobs
  end
end
