class SalesforceImportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    SFImport.poll_jobs
  end
end
