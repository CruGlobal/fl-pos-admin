class WooImport
  SHEET_ID = ENV["GOOGLE_SHEET_ID"]
  SHEETS_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS
  WOO_LIMIT = (ENV["WOO_LIMIT"] || "0").to_i

  def products
    @products ||= WooProduct.all
  end

  def sheet(event_code)
    @sheet ||= sheets.get_spreadsheet(SHEET_ID)
    @sheet.sheets.find { |s| s.properties.title == event_code }
  end

  def initialize
  end

  def woo
    @woo ||= WooCommerce::API.new(
      ENV["WOO_API_URL"].to_s,
      ENV["WOO_API_KEY"].to_s,
      ENV["WOO_API_SECRET"].to_s,
      {
        version: "wc/v3",
        wp_api: true
      }
    )
  end

  def sheets
    @sheets ||= Google::Apis::SheetsV4::SheetsService.new
    @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(scope: SHEETS_SCOPE)
    @sheets
  end

  def create_job
    job = Job.create
    job.type = "WOO_IMPORT"
    job.save!
    job
  end

  def log job, message
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    log = job.logs.create(content: "[#{timestamp}] #{message}")
    log.save!
    Rails.logger.info log.content
  end

  def poll_jobs
    # if there are any current WOO_REFRESH jobs running, don't start another one
    if Job.where(type: "WOO_REFRESH", status: :processing).count > 0
      Rails.logger.info "POLLING: A WOO_REFRESH job is currently running."
      WoocommerceImportJob.set(wait: 5.minutes).perform_later
      return
    end
    if Job.where(type: "WOO_IMPORT", status: :processing).count > 0
      Rails.logger.info "POLLING: A WOO_IMPORT job is currently running or failed unexpectedly. Will not start another job."
      return
    end

    jobs_to_run = Job.where(type: "WOO_IMPORT", status: [:created, :paused, :error])
    if jobs_to_run.count == 0
      Rails.logger.info "POLLING: No WOO_IMPORT jobs found."
      return
    end
    # Mark all found jobs as paused
    jobs_to_run.each do |job|
      job.status_paused!
    end
    # Run each job sequentially
    jobs_to_run.each do |job|
      Rails.logger.info "POLLING: Found job #{job.id}. Starting job."
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
    context = JSON.parse(context) if context.is_a? String

    # Get values from spreadsheet as objects
    if context["sheet"].nil?
      log job, "Getting rows from sheet"
      context["sheet"] = sheet(job.event_code)
      context["rows"] = sheets.get_spreadsheet_values(SHEET_ID, "#{job.event_code}!A:AC").values
      job.context = context.to_json
      job.save!
      log job, "Got #{context["rows"].count} rows from sheet"
    end

    if context["woo_list"].nil?
      log job, "Building list of sales to send to woo"
      context["woo_list"] = build_woo_list(context["rows"], job.event_code)
      job.context = context.to_json
      job.save!
      log job, "Built list of #{context["woo_list"].count} sales to send to woo"
    end

    context["woo_list"] = send_to_woo(context["woo_list"], job)
    job.context = context.to_json
    job.save!

    # Check all orders to make sure they were created successfully
    success = true
    context["woo_list"].each do |order|
      next if order["id"].is_a? Integer
      success = false
    end

    if success
      set_ready_status job.event_code, sheet_status_index(job), "IMPORTED TO WOO"
      job.status_complete!
    elsif context["retry_count"].nil? || context["retry_count"] < 4 # If any orders failed to create, mark the job as failed
      set_ready_status job.event_code, sheet_status_index(job), "PROCESSING"
      log job, "Not all orders were created successfully. Pausing to try again later."
      context["retry_count"] = context["retry_count"].nil? ? 1 : context["retry_count"] + 1
      job.context = context.to_json
      job.status_paused!
    else
      set_ready_status job.event_code, sheet_status_index(job), "ERROR"
      log job, "Job failed after 3 retries"
      job.status_error!
    end
  end

  def set_ready_status event_code, index, status
    range = "#{event_code}!A#{index}:B"
    values = [
      ["Status", status]
    ]
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    sheets.update_spreadsheet_value(SHEET_ID, range, value_range, value_input_option: "RAW")
  end

  def send_to_woo(woo_list, job)
    woo_list.each do |order|
      next if order["id"].is_a? Integer

      response = woo.post("orders", order)
      if response["id"].is_a? Integer
        log job, "Order #{response["id"]} created"
        order["id"] = response["id"]
      else
        log job, "Order creation failed: #{response}"
        order["error"] = response.body
      end
    end
    woo_list
  end

  def build_woo_list(rows, event_code)
    build_column_hash(rows[0])

    objects = []
    count = 0
    rows.each do |row|
      object = get_create_object(row, event_code)
      objects << object if object.present?
      count += 1
      break if WOO_LIMIT.positive? && count >= WOO_LIMIT
    end
    objects
  end

  def build_column_hash(row)
    return @columns if @columns.present?

    @columns = {}
    row.each_with_index do |cell, index|
      @columns[cell] = index
    end
    @columns
  end

  def get_create_object(row, event_code)
    return unless row.first == event_code

    email_address = row[@columns["EmailAddress"]].present? ? row[@columns["EmailAddress"]] : "fleventanonymoussales@familylife.com"
    # If email address is pipe or comma separated, split and use the first email address
    email_address = email_address.split(/[,|;]/).first.strip
    status = (row[@columns["SpecialOrderFlag"]] == "Y") ? "processing" : "completed"
    line_items = get_row_items(row)
    # LastName needs to be stripped of everything after the asterisk and trimmed to remove trailing whitespace
    last_name = row[@columns["LastName"]].split("*")[0].strip
    create_object = {
      status: status,
      billing: {
        first_name: row[@columns["FirstName"]],
        last_name: last_name,
        address_1: row[@columns["AddressLine1"]],
        address_2: row[@columns["AddressLine2"]],
        city: row[@columns["City"]],
        state: row[@columns["State"]],
        postcode: row[@columns["ZipPostal"]],
        country: row[@columns["Country"]],
        email: email_address
      },
      line_items: line_items,
      meta_data: [
        {
          key: "cru_order_origin",
          value: "POS import"
        },
        {
          key: "event_transaction",
          value: "#{row[@columns["EventCode"]]}-#{row[@columns["SaleID"]]}"
        },
        {
          key: "event_code",
          value: row[@columns["EventCode"]]
        },
        {
          key: "transaction_notes",
          value: row[@columns["SaleID"]]
        }
      ]
    }
    if row[@columns["SpecialOrderFlag"]] == "Y"
      create_object[:shipping_lines] = []
      create_object[:shipping_lines] << {
        method_id: "free_shipping",
        method_title: "Free Standard Shipping",
        total: "0.00"
      }
    end
    # If there is a shipping address, add it to the object
    if row[@columns["ShipAddressLine1"]].present?
      create_object[:shipping] = {
        first_name: row[@columns["FirstName"]],
        last_name: row[@columns["LastName"]],
        address_1: row[@columns["ShipAddressLine1"]],
        address_2: row[@columns["ShipAddressLine2"]],
        city: row[@columns["ShipCity"]],
        state: row[@columns["ShipState"]],
        postcode: row[@columns["ShipZipPostal"]],
        country: row[@columns["ShipCountry"]],
        email: email_address
      }
    end
    puts create_object.inspect
    create_object
  end

  def get_row_items(row)
    count = row[@columns["ProductCode"]].split("|").count
    items = []
    # Round to currency format
    count.times do |i|
      items << {
        sku: row[@columns["ProductCode"]].split("|")[i],
        quantity: row[@columns["Quantity"]].split("|")[i].to_i,
        total_tax: row[@columns["ItemSalesTax"]].split("|")[i],
        total: row[@columns["UnitPrice"]].split("|")[i],
        subtotal_tax: row[@columns["ItemSalesTax"]].split("|")[i],
        subtotal: row[@columns["UnitPrice"]].split("|")[i]
      }
    end
    items
  end

  def get_spreadsheet(job)
    response = sheets.get_spreadsheet(SHEET_ID)
    values = []
    response.sheets.each do |s|
      next if job.event_code != s.properties.title

      # Find the first row with an empty first cell in the row
      range = "#{job.event_code}!A1:AC"
      response = sheets.get_spreadsheet_values(SHEET_ID, range, value_render_option: "UNFORMATTED_VALUE")
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
      next if row[0].nil? || row[0].empty? || row[0] == "Status"

      row_hash = {}
      row.each_with_index do |cell, index|
        row_hash[columns[index]] = cell
      end
      rows << row_hash
      count += 1
    end
    rows
  end

  def sheet_status_index(job)
    return @index if @index.present?

    sheets.get_spreadsheet_values(SHEET_ID, "#{job.event_code}!A:AC").values.each_with_index do |row, index|
      if row[0] == "Status"
        @index = index + 1 # Add 1 to the array index to get the row number
        break
      end
    end

    @index
  end
end
