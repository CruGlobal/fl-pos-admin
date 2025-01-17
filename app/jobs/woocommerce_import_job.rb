class WoocommerceImportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    WooImport.new.poll_jobs
  end
end
