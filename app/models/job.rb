class Job < ApplicationRecord
  # Turn off single table inheritance
  self.inheritance_column = nil
  has_many :logs, foreign_key: "jobs_id", class_name: "AppLog", dependent: :destroy
  enum :status, [:created, :processing, :error, :complete, :paused], prefix: true, default: :created
  TYPE = ["WOO_IMPORT", "LS_EXTRACT", "SF_IMPORT", "WOO_REFRESH", "POLL_SHEET"]
  STATUS = ["created", "processing", "error", "complete", "paused"]

  def restart_job
    update(status: :created)
    case type
    when "WOO_IMPORT"
      WoocommerceImportJob.perform_later
    when "LS_EXTRACT"
      LightspeedExtractJob.perform_later
    when "SF_IMPORT"
      SalesforceImportJob.perform_later
    when "WOO_REFRESH"
      WoocommerceRefreshJob.perform_later
    when "POLL_SHEET"
      PollSheetJob.perform_later
    else
      false
    end
  end
end
