class LightspeedExtractJob < ApplicationJob
  queue_as :default

  def perform(*args)
    LSExtract.poll_jobs
  end
end
