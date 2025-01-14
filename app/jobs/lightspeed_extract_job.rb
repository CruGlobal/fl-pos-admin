class LightspeedExtractJob < ApplicationJob
  queue_as :default

  def perform(*args)
    LSExtract.new.poll_jobs
  end
end
