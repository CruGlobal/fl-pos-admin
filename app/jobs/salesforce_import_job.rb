class SalesforceImportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    SFImport.new.poll_jobs
  end
end
