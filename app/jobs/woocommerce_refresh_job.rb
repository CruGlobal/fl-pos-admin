class WoocommerceRefreshJob < ApplicationJob
  queue_as :default

  def perform(*args)
    WooRefresh.poll_jobs
  end
end
