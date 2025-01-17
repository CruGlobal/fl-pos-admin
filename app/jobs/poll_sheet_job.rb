class PollSheetJob < ApplicationJob
  queue_as :default

  def perform(*args)
    ps = PollSheet.new
    ps.create_job
    ps.poll_jobs
  end
end
