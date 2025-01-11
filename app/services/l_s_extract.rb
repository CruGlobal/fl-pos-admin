class LSExtract

  # Google Sheets Service Instance
  @sheets = nil

  # Lightspeed API Helper
  @lsh = nil

  SHEET_ID = ENV['GOOGLE_SHEET_ID']
  SHEETS_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS


  def initialize
    @lsh = LightspeedApiHelper.new
    @sheets = Google::Apis::SheetsV4::SheetsService.new
    @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(scope: SHEETS_SCOPE)
  end

  def get_products(limit = 0)
    if(limit == 0)
      return WooProduct.all
    end
    WooProduct.all.limit(limit)
  end

  def create_job(shop_id, start_date, end_date)
    shop = @lsh.find_shop(shop_id)
    context = {
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: shop.Contact['custom']
    }
    job = Job.create(
      type: 'LS_EXTRACT',
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: shop.Contact['custom'],
      context: context
    )
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
    jobs = Job.where('type': 'LS_EXTRACT', status: :status_created).all
    if jobs.count == 0
      puts "POLLING: No LS_EXTRACT jobs found."
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
    # Get list of all sales for the shop_id between start_date and end_date (paging included)
    context['sales'] = @lsh.get_sales(job, context['shop_id'], context['start_date'], context['end_date'])
    # Optimize sales data to remove extreneous data from the Object
    context['sales'] = context['sales'].map { |sale| @lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep) }
    # delete the sales variable to free up memory
    # Save the sales data to the context object
    job.context = context
    job.save!
    log job, "Sales retrieved from Lightspeed"
    # Generate the report
    context['report'] = generate_report(job,context['sales'])
    job.context = context
    job.save!
    log job, "Report generated and saved locally"
    put_sheet job
    log job, "Report saved to Google Sheets"
    job.status_complete!
    job.save!
  end

  def is_bundle?(sku, products)
    products.each do |product|
      if product['sku'] == sku
        return product['type'] == 'bundle'
      end
    end
  end

  def generate_report(job,sales)
    products = get_products
    shipping_customers = @lsh.get_shipping_customers(job, sales)
    lines = []
    sales.each do |sale|
      lines << get_report_line(job, sale, products, shipping_customers)
    end
    lines
  end

  def get_report_line(job,sale,products,customers)
    {
      EventCode: job.event_code,
      SaleID: sale['saleID'],
      OrderDate: sale['timeStamp'].to_date.strftime('%Y-%m-%d'),
      Customer: "#{sale['Customer']['firstName']} #{sale['Customer']['lastName']}",
      FirstName: sale['Customer']['firstName'],
      LastName: sale['Customer']['lastName'],
      OrderTotal: sale['calcTotal'],
      ItemSubtotal: sale['calcSubtotal'],
      SalesTax: (sale['calcTax1'].to_f + sale['calcTax2'].to_f).round(2),
      SpecialOrderFlag: @lsh.get_special_order_flag(sale),
      TaxableOrderFlag: @lsh.get_taxable_order_flag(sale),
      ProductCode: @lsh.get_all_product_codes(sale).join('|'),
      Quantity: @lsh.get_all_quantities(sale).join('|'),
      UnitPrice: @lsh.get_all_unit_prices(sale).join('|'),
      ItemSalesTax: @lsh.get_all_unit_taxes(sale).join('|'),
      AddressLine1: @lsh.get_address(sale,'address1'),
      AddressLine2: '',
      City: @lsh.get_address(sale,'city'),
      State: @lsh.get_address(sale,'state'),
      ZipPostal: @lsh.get_address(sale,'zip'),
      Country: 'US',
      ShipAddressLine1: @lsh.get_shipping_address(sale, customers,'address1'),
      ShipAddressLine2: '',
      ShipCity: @lsh.get_shipping_address(sale, customers,'city'),
      ShipState: @lsh.get_shipping_address(sale, customers,'state'),
      ShipZipPostal: @lsh.get_shipping_address(sale, customers,'zip'),
      ShipCountry: 'US',
      EmailAddress: @lsh.get_email_addresses(sale).join('|'),
      POSImportID: sale['saleID']
    }
  end

  def put_sheet(job)
    report = job.context['report']
    headers = [
      'EventCode',
      'SaleID',
      'OrderDate',
      'Customer',
      'FirstName',
      'LastName',
      'OrderTotal',
      'ItemSubtotal',
      'SalesTax',
      'SpecialOrderFlag',
      'TaxableOrderFlag',
      'ProductCode',
      'Quantity',
      'UnitPrice',
      'ItemSalesTax',
      'AddressLine1',
      'AddressLine2',
      'City',
      'State',
      'ZipPostal',
      'Country',
      'ShipAddressLine1',
      'ShipAddressLine2',
      'ShipCity',
      'ShipState',
      'ShipZipPostal',
      'ShipCountry',
      'EmailAddress',
      'POSImportID'
    ]

    rows = [headers]
    report.each do |line|
      row = []
      headers.each do |header|
        row << line[header]
      end
      rows << row
    end
    write_range = "#{job.event_code}!A1:AC#{rows.count}"
    clear_range = "#{job.event_code}!A1:AC9999"
    value_range_object = {
      "major_dimension": "ROWS",
      "values": rows
    }


    # make sure tab exists first
    response = @sheets.get_spreadsheet(SHEET_ID)
    tab = response.sheets.select { |s| s.properties.title == job.event_code }.first

    unless tab
      request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(
        requests: [
          {
            add_sheet: {
              properties: {
                title: job.event_code,
                grid_properties: {
                  frozen_row_count: 1
                },
                fields: 'gridProperties.frozenRowCount'
              }
            }
          }
        ]
      )
      begin
        @sheets.batch_update_spreadsheet(SHEET_ID, request)
        response = @sheets.get_spreadsheet(SHEET_ID)
        tab = response.sheets.select { |s| s.properties.title == job.event_code }.first
      rescue Google::Apis::ClientError => e
        throw e
      rescue Google::Apis::AuthorizationError => e
        puts "Authorization error: #{e.message}"
      rescue StandardError => e
        puts "An error occurred: #{e.message}"
      end
    end
    if tab
      puts "Tab '#{job.event_code}' exists."
      @sheets.clear_values(SHEET_ID, clear_range)
    end
    begin
      puts "Writing tab '#{job.event_code}'"
      @sheets.update_spreadsheet_value(SHEET_ID, write_range, value_range_object, value_input_option: 'RAW')
      request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(
        requests: [
          {
            update_sheet_properties: {
              properties: {
                sheet_id: tab.properties.sheet_id,
                grid_properties: {
                  frozen_row_count: 1
                }
              },
              fields: 'gridProperties.frozenRowCount'
            }
          },
          {
            repeat_cell: {
              range: {
                sheet_id: tab.properties.sheet_id,
                start_row_index: 0,
                end_row_index: 1,
                start_column_index: 0,
                end_column_index: rows.first.size
              },
              cell: {
                user_entered_format: {
                  background_color: { red: 0.9, green: 0.9, blue: 0.9 },
                  text_format: { bold: true }
                }
              },
              fields: 'userEnteredFormat(backgroundColor,textFormat)'
            }
          },
          {
            set_data_validation: {
              range: {
                sheet_id: tab.properties.sheet_id,
                start_row_index: rows.count + 1,
                end_row_index: rows.count + 2,
                start_column_index: 1,
                end_column_index: 2
              },
              rule: {
                condition: {
                  type: 'ONE_OF_LIST',
                  values: [
                    { user_entered_value: 'IN REVIEW' },
                    { user_entered_value: 'READY FOR WOO IMPORT' },
                    { user_entered_value: 'PROCESSING' },
                    { user_entered_value: 'IMPORTED TO WOO' },
                    { user_entered_value: 'ERROR' }
                  ]
                },
                show_custom_ui: true,
                strict: true
              }
            }
          },
          {
            update_cells: {
              rows: [
                {
                  values: [
                    { user_entered_value: { string_value: 'Status' } },
                    { user_entered_value: { string_value: 'IN REVIEW' } }
                  ]
                }
              ],
              start: { 
                sheet_id: tab.properties.sheet_id,
                row_index: rows.count + 1,
                column_index: 0
              },
              fields: 'userEnteredValue'
            }
          },
          {
            add_conditional_format_rule: {
              rule: {
                ranges: [
                  {
                    sheet_id: tab.properties.sheet_id,
                    start_row_index: rows.count + 1,
                    end_row_index: rows.count + 2,
                    start_column_index: 1,
                    end_column_index: 2
                  }
                ],
                boolean_rule: {
                  condition: {
                    type: 'TEXT_EQ',
                    values: [
                      { user_entered_value: 'IN REVIEW' }
                    ]
                  },
                  format: {
                    background_color: { red: 0.9, green: 0.9, blue: 0.9 } # Red for YES
                  }
                }
              }
            }
          },
          {
            add_conditional_format_rule: {
              rule: {
                ranges: [
                  {
                    sheet_id: tab.properties.sheet_id,
                    start_row_index: rows.count + 1,
                    end_row_index: rows.count + 2,
                    start_column_index: 1,
                    end_column_index: 2
                  }
                ],
                boolean_rule: {
                  condition: {
                    type: 'TEXT_EQ',
                    values: [
                      { user_entered_value: 'READY FOR WOO IMPORT' }
                    ]
                  },
                  format: {
                    background_color: { red: 0.5, green: 1.0, blue: 0.5 } # Green for NO
                  }
                }
              }
            }
          },
          {
            add_conditional_format_rule: {
              rule: {
                ranges: [
                  {
                    sheet_id: tab.properties.sheet_id,
                    start_row_index: rows.count + 1,
                    end_row_index: rows.count + 2,
                    start_column_index: 1,
                    end_column_index: 2
                  }
                ],
                boolean_rule: {
                  condition: {
                    type: 'TEXT_EQ',
                    values: [
                      { user_entered_value: 'ERROR' }
                    ]
                  },
                  format: {
                    background_color: { red: 1.0, green: 0.5, blue: 0.5 } # Green for NO
                  }
                }
              }
            }
          },
          {
            add_conditional_format_rule: {
              rule: {
                ranges: [
                  {
                    sheet_id: tab.properties.sheet_id,
                    start_row_index: rows.count + 1,
                    end_row_index: rows.count + 2,
                    start_column_index: 1,
                    end_column_index: 2
                  }
                ],
                boolean_rule: {
                  condition: {
                    type: 'TEXT_EQ',
                    values: [
                      { user_entered_value: 'IMPORTED TO WOO' }
                    ]
                  },
                  format: {
                    background_color: { red: 0.8, green: 0.8, blue: 1.0 } # Green for NO
                  }
                }
              }
            }
          },
          {
            repeat_cell: {
              range: {
                sheet_id: tab.properties.sheet_id,
                start_row_index: rows.count + 1,
                end_row_index: rows.count + 2,
                start_column_index: 0,
                end_column_index: 2
              },
              cell: {
                user_entered_format: {
                  background_color: { red: 0.9, green: 0.9, blue: 0.9 },
                  text_format: { bold: true }
                }
              },
              fields: 'userEnteredFormat(backgroundColor,textFormat)'
            }
          }
        ]
      )
      @sheets.batch_update_spreadsheet(SHEET_ID, request)
      puts "Tab '#{job.event_code}' created successfully."
    rescue Google::Apis::ClientError => e
      throw e
    rescue Google::Apis::AuthorizationError => e
      puts "Authorization error: #{e.message}"
    rescue StandardError => e
      puts "An error occurred: #{e.message}"
    end

  end

  def complete_job(job)
    # TODO
    # Get job record from the jobs table
    # Update the job status to COMPLETED
  end

end
