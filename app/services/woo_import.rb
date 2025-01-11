
class WooImport
  @woo = nil
  @sheets = nil
  @products = nil
  @sheet = nil

  SHEET_ID = ENV['GOOGLE_SHEET_ID']
  SHEETS_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS

  def woo
    @woo
  end

  def sheets
    @sheets
  end

  def products
    @products ||= WooProduct.all
  end

  def sheet
    @sheet ||= sheets.get_spreadsheet
  end

  def initialize
    @woo = WooCommerce::API.new(
      ENV['WOO_API_URL'].to_s,
      ENV['WOO_API_KEY'].to_s,
      ENV['WOO_API_SECRET'].to_s,
      {
        version: "wc/v3",
        wp_api: true,
      }
    )
    @sheets = Google::Apis::SheetsV4::SheetsService.new
    @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(scope: SHEETS_SCOPE)
  end

  def create_job
    job = Job.create
    job.type = 'WOO_IMPORT'
    job.save!
    job
  end

  def log job, message
    log = job.logs.create(content: "[LS_EXTRACT] #{message}")
    log.save!
    puts log.content
  end

  def poll_jobs
    # if there are any current WOO_REFRESH jobs running, don't start another one
    if Job.where('type': 'WOO_REFRESH', status: :status_processing).count > 0
      puts "POLLING: A WOO_REFRESH job is currently running."
      return
    end
    jobs = Job.where('type': 'WOO_IMPORT', status: :status_created).all
    if jobs.count == 0
      puts "POLLING: No WOO_IMPORT jobs found."
      return
    end
    # Mark all found jobs as paused
    jobs.each do |job|
      job.status_paused!
      job.save!
    end
    jobs.each do |job|
      puts "POLLING: Found job #{job.id}. Starting job."
      handle_job job
    end
  end

  def handle_job(job)
    # Process the job
    job.status_processing!
    job.save!
    log job, "Processing job #{job.id}"
    # Get the job context, which is a jsonb store in the context column
    context = job.context

    # Get values from spreadsheet as objects
    log job, "Getting rows from sheet"
    context['sheet'] = sheet
    log job, "Got #{context['sheet'].count} rows from sheet"

    log job, "Building list of sales to send to woo"
    context['woo_list'] = build_woo_list(context['sheet'])
    log job, "Built list of #{context['woo_list'].count} sales to send to woo"

    job.status_complete!
    job.save!
  end

  def build_woo_list(sheet)
  end

  def get_spreadsheet(job)
    response = @sheets.get_spreadsheet(SHEET_ID)
    values = [];
    response.sheets.each do |s|
      next if job.event_code != s.properties.title

      # Find the first row with an empty first cell in the row
      range = "#{job.event_code}!A1:AC"
      response = @sheets.get_spreadsheet_values(SHEET_ID, range, value_render_option: 'UNFORMATTED_VALUE')
      values = response.values
    end
    return nil if values.empty?

    rows = []
    count = 0
    columns = []
    values.each do |row|
      if count == 0
        columns = row
        count += 1
        next
      end
      next if row[0].nil? || row[0].empty? || row[0] == 'Status'

      row_hash = {}
      row.each_with_index do |cell, index|
        row_hash[columns[index]] = cell
      end
      rows << row_hash
      count += 1
    end
    rows
  end

end
