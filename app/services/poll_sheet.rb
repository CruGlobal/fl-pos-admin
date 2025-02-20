class PollSheet
  SHEET_ID = ENV["GOOGLE_SHEET_ID"]
  SHEETS_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS

  def initialize
  end

  def sheets
    @sheets ||= Google::Apis::SheetsV4::SheetsService.new
    @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(scope: SHEETS_SCOPE)
    @sheets
  end

  def create_job
    job = Job.create
    job.type = "POLL_SHEET"
    job.save!
    job.status_created!
    job
  end

  def log job, message
    log = job.logs.create(content: "[POLL_SHEET] #{message}")
    log.save!
    Rails.logger.info log.content
  end

  def poll_jobs
    jobs = Job.where(type: "POLL_SHEET", status: :created).all
    if jobs.count == 0
      Rails.logger.info "POLLING: No POLL_SHEET jobs found."
      return
    end
    # Delete all POLL_SHEET jobs that are older than 1 day
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("DELETE FROM logs WHERE jobs_id IN (SELECT id FROM jobs WHERE type = 'POLL_SHEET' AND created_at < NOW() - INTERVAL '1 day')")
      ActiveRecord::Base.connection.execute("DELETE FROM jobs WHERE type = 'POLL_SHEET' AND created_at < NOW() - INTERVAL '1 day'")
    end
    # Mark all found jobs as paused
    jobs.each do |job|
      job.status_paused!
      job.save!
    end
    jobs.each do |job|
      Rails.logger.info "POLLING: Found job #{job.id}. Starting job."
      handle_job job
    end
  end

  def handle_job job
    job.status_processing!
    job.save!
    log job, "Processing job #{job.id}"
    ready_sheets = get_ready_sheets
    if ready_sheets.empty?
      log job, "No ready sheets found."
      job.status_complete!
      job.save!
      return
    end
    ready_sheets.each do |row|
      tab_event_code = row[0]
      index = row[1]
      # Create a new WOO_IMPORT job for each tab only if a job by the same
      # event_code does not already exist
      woo_job = Job.where(type: "WOO_IMPORT", event_code: tab_event_code).first
      if woo_job
        log job, "Job for event code #{tab_event_code} already exists. Skipping."
        next
      end

      woo_job = Job.create
      woo_job.type = "WOO_IMPORT"
      woo_job.event_code = tab_event_code
      woo_job.save!
      woo_job.status_created!
      set_ready_status tab_event_code, index, "PROCESSING"
      log job, "Created WOO_IMPORT job #{woo_job.id} for event code #{tab_event_code}"
    end
    WoocommerceImportJob.perform_later
    job.status_complete!
    job.save!
  end

  def get_ready_sheets
    ready_sheets = []
    # make sure tab exists first
    response = sheets.get_spreadsheet(SHEET_ID)
    response.sheets.each do |s|
      tab_event_code = s.properties.title
      # Find the first row with an empty first cell in the row
      range = "#{tab_event_code}!A1:B"
      response = sheets.get_spreadsheet_values(SHEET_ID, range, value_render_option: "UNFORMATTED_VALUE")
      values = response.values
      index = 0
      values.each do |row|
        index += 1
        next if row[0].nil? || row[0].empty?
        if row[0] == "Status" && row[1] == "READY FOR WOO IMPORT"
          ready_sheets << [tab_event_code, index]
        end
      end
    end
    ready_sheets
  end

  def set_ready_status event_code, index, status
    range = "#{event_code}!A#{index}:B"
    values = [
      ["Status", status]
    ]
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    sheets.update_spreadsheet_value(SHEET_ID, range, value_range, value_input_option: "RAW")
  end
end
