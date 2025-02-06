class CleanJobsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    cj = CleanJobs.new
    cj.create_job
    cj.poll_jobs
  end
end
