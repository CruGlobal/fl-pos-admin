class WooImport
  @woo = nil
  @sheets = nil
  @products = nil
  @sheet = nil

  SHEET_ID = ENV["GOOGLE_SHEET_ID"]
  SHEETS_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS

  attr_reader :woo

  attr_reader :sheets

  def products
    @products ||= WooProduct.all
  end

  def sheet
    @sheet ||= sheets.get_spreadsheet
  end

  def initialize
    @woo = WooCommerce::API.new(
      ENV["WOO_API_URL"].to_s,
      ENV["WOO_API_KEY"].to_s,
      ENV["WOO_API_SECRET"].to_s,
      {
        version: "wc/v3",
        wp_api: true
      }
    )
    @sheets = Google::Apis::SheetsV4::SheetsService.new
    @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(scope: SHEETS_SCOPE)
  end

  def create_job
    job = Job.create
    job.type = "WOO_IMPORT"
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
    if Job.where(type: "WOO_REFRESH", status: :status_processing).count > 0
      puts "POLLING: A WOO_REFRESH job is currently running."
      return
    end
    jobs = Job.where(type: "WOO_IMPORT", status: [:status_created, :status_paused]).all
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
    if context["sheet"].nil?
      log job, "Getting rows from sheet"
      context["sheet"] = sheet
      job.context = context.to_json
      job.save!
      log job, "Got #{context["sheet"].count} rows from sheet"
    end

    if context["woo_list"].nil?
      log job, "Building list of sales to send to woo"
      context["woo_list"] = build_woo_list(context["sheet"])
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
      set_ready_status job.event_code, 1, "IMPORTED TO WOO"
      job.status_complete!
      job.save!
      elseif context["retry_count"].nil? || context["retry_count"] < 4 # If any orders failed to create, mark the job as failed
      set_ready_status job.event_code, 1, "PROCESSING"
      log job, "Not all orders were created successfully. Pausing to try again later."
      context["retry_count"] = context["retry_count"].nil? ? 1 : context["retry_count"] + 1
      job.context = context.to_json
      job.status_paused!
      job.save!
    else
      set_ready_status job.event_code, 1, "ERROR"
      log job, "Job failed after 3 retries"
      job.status_error!
      job.save!
    end
  end

  def set_ready_status event_code, index, status
    range = "#{event_code}!A#{index}:B"
    values = [
      ["Status", status]
    ]
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @sheets.update_spreadsheet_value(SHEET_ID, range, value_range, value_input_option: "RAW")
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

  def build_woo_list(sheet)
    objects = []
    sheet.each do |row|
      objects << get_create_object(row)
    end
    objects
  end

  def get_create_object(row)
    email_address = row["EmailAddress"].present? ? row["EmailAddress"] : "fleventanonymoussales@familylife.com"
    status = (row["SpecialOrderFlag"] == "Y") ? "processing" : "completed"
    line_items = get_row_items(row)
    # LastName needs to be stripped of everything after the asterisk and trimmed to remove trailing whitespace
    last_name = row["LastName"].split("*")[0].strip
    create_object = {
      status: status,
      billing: {
        first_name: row["FirstName"],
        last_name: last_name,
        address_1: row["AddressLine1"],
        address_2: row["AddressLine2"],
        city: row["City"],
        state: row["State"],
        postcode: row["ZipPostal"],
        country: row["Country"],
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
          value: "#{row["EventCode"] = row["SaleID"]}"
        },
        {
          key: "event_code",
          value: row["EventCode"]
        },
        {
          key: "transaction_notes",
          value: row["SaleID"]
        }
      ]
    }
    # If there is a shipping address, add it to the object
    if row["ShipAddressLine1"].present?
      create_object["shipping"] = {
        first_name: row["FirstName"],
        last_name: row["LastName"],
        address_1: row["ShipAddressLine1"],
        address_2: row["ShipAddressLine2"],
        city: row["ShipCity"],
        state: row["ShipState"],
        postcode: row["ShipZipPostal"],
        country: row["ShipCountry"],
        email: email_address
      }
    end
    create_object
  end

  def get_row_items(row)
    count = row["ProductCode"].split("|").count
    items = []
    count.times do |i|
      items << {
        sku: row["ProductCode"].split("|")[i],
        quantity: row["Quantity"].split("|")[i].to_i,
        subtotal_tax: row["ItemSalesTax"].split("|")[i],
        subtotal: row["UnitPrice"].split("|")[i]
      }
    end
    items
  end

  def get_spreadsheet(job)
    response = @sheets.get_spreadsheet(SHEET_ID)
    values = []
    response.sheets.each do |s|
      next if job.event_code != s.properties.title

      # Find the first row with an empty first cell in the row
      range = "#{job.event_code}!A1:AC"
      response = @sheets.get_spreadsheet_values(SHEET_ID, range, value_render_option: "UNFORMATTED_VALUE")
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
end
