class LSExtract
  SHEET_ID = ENV["GOOGLE_SHEET_ID"]
  SHEETS_SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS
  SPECIAL_ORDER_SKU = "MSC17061"
  CUSTOMER_ANONYMOUS_EMAIL = "fleventanonymoussales@familylife.com"

  def initialize
  end

  def sf_client
    @sf_client ||= Restforce.new(
      username: ENV["SF_USERNAME"],
      password: ENV["SF_PASSWORD"],
      security_token: ENV["SF_TOKEN"],
      instance_url: ENV["SF_INSTANCE_URL"],
      host: ENV["SF_HOST"],
      client_id: ENV["SF_CLIENT_ID"],
      client_secret: ENV["SF_CLIENT_SECRET"]
    )
  end

  def lsh
    @lsh ||= LightspeedApiHelper.new
  end

  def sheets
    @sheets = Google::Apis::SheetsV4::SheetsService.new
    @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(scope: SHEETS_SCOPE)
    @sheets
  end

  def get_products(limit = 0)
    if limit == 0
      return WooProduct.all
    end
    WooProduct.all.limit(limit)
  end

  def create_job(shop_id, start_date, end_date)
    # Get the shop from Lightspeed
    shop = lsh.find_shop(shop_id)

    # Grab the event_code
    event_code = shop.Contact["custom"]
    # Now use the event_code to get the event address from SalesForce
    event_address = get_event_address(event_code)
    shop_name = shop.name.gsub("EVENT - ", "")

    context = {
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: event_code,
      event_address: event_address,
      shop_name: shop_name
    }
    job = Job.create(
      type: "LS_EXTRACT",
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: event_code,
      context: context,
      status: :created
    )
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
      LightspeedExtractJob.set(wait: 5.minutes).perform_later
      return
    end
    jobs = Job.where(type: "LS_EXTRACT", status: :created).all
    if jobs.count == 0
      Rails.logger.info "POLLING: No LS_EXTRACT jobs found."
      return
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

  def handle_job(job)
    # Process the job
    job.status_processing!
    job.save!
    log job, "Processing job #{job.id}"
    # Get the job context, which is a jsonb store in the context column
    context = job.context
    # Get list of all sales for the shop_id between start_date and end_date (paging included)
    context["sales"] = lsh.get_sales(job, context["shop_id"], context["start_date"], context["end_date"])
    log job, "Sales retrieved from Lightspeed"
    division_result = context["sales"].count / 300
    minutes = (division_result.zero? ? 1 : division_result) * 10
    log job, "Optimizing for storage. This may take up to #{minutes} minutes."
    # Optimize sales data to remove extreneous data from the Object
    context["sales"] = context["sales"].map { |sale| lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep) }
    log job, "Sales optimized"
    # delete the sales variable to free up memory
    # Save the sales data to the context object
    job.context = context
    job.save!
    log job, "Sales stored locally"
    # Generate the report
    report = generate_report(job, context["sales"])
    log job, "Report generated"
    report = process_report(report)
    log job, "Refunds squashed"
    context["report"] = report
    job.context = context
    job.save!
    log job, "Report saved locally"
    put_sheet job
    log job, "Report saved to Google Sheets"
    job.status_complete!
    job.save!
  end

  def get_event_address(event_code)
    return @event_address if @event_address

    soql = "SELECT Id,
      Conference_Location__r.Name,
      Conference_Location__r.ShippingStreet,
      Conference_Location__r.ShippingCity,
      Conference_Location__r.ShippingState,
      Conference_Location__r.ShippingPostalCode
      FROM Event_Details__c
      WHERE EventCode__c = '#{event_code}'"
    sf_address = sf_client.query(soql).first
    return unless sf_address && sf_address["Conference_Location__r"]
    
    street = sf_address["Conference_Location__r"]["ShippingStreet"]
    address1, address2 = street.split("\n") if street
    @event_address = {
      address1: address1,
      address2: address2,
      city: sf_address["Conference_Location__r"]["ShippingCity"],
      state: sf_address["Conference_Location__r"]["ShippingState"],
      zip: sf_address["Conference_Location__r"]["ShippingPostalCode"]
    }
  end

  def process_report(report)
    report = remove_refunds(report)
    remove_shipping_product_codes(report)
  end

  def remove_refunds(report)
    # Cancel out refunds
    refund_lines = report.select { |line| line[:OrderTotal] < 0 }
    refund_lines.each do |refund_line|
      refunded_product_codes = refund_line[:ProductCode].split("|")
      email = refund_line[:EmailAddress]
      customer_lines = report.select { |line| line[:EmailAddress] == email }
      customer_lines.delete(refund_line) # Don't refund the refund line itself

      # Find the original sale
      customer_lines.each do |customer_line|
        product_codes = customer_line[:ProductCode].split("|")
        order_total = customer_line[:OrderTotal]
        item_subtotal = customer_line[:ItemSubtotal]
        sales_tax = customer_line[:SalesTax]

        product_codes.dup.each do |product_code|
          if refunded_product_codes.include?(product_code)
            sale_line_product_code_index = product_codes.index(product_code)

            # Update quantities
            quantities = customer_line[:Quantity].split("|")
            refunded_quantity = refund_line[:Quantity].split("|")[refunded_product_codes.index(product_code)].to_i
            quantities[sale_line_product_code_index] = (quantities[sale_line_product_code_index].to_i + refunded_quantity).to_s
            customer_line[:Quantity] = quantities.join("|")

            # Remove item from sale line completely if quantity is 0
            if quantities[sale_line_product_code_index].to_i <= 0
              quantities.delete_at(sale_line_product_code_index)
              customer_line[:Quantity] = quantities.join("|")

              # Update unit prices
              unit_prices = customer_line[:UnitPrice].split("|")
              unit_prices.delete_at(sale_line_product_code_index)
              customer_line[:UnitPrice] = unit_prices.join("|")

              # Update item sales tax
              item_sales_taxes = customer_line[:ItemSalesTax].split("|")
              item_sales_taxes.delete_at(sale_line_product_code_index)
              customer_line[:ItemSalesTax] = item_sales_taxes.join("|")

              # Remove the refunded product from the product code list
              product_codes.delete(product_code)
              customer_line[:ProductCode] = product_codes.join("|")
            end

            # Remove the sale line if it was the only/last item in the sale
            if product_codes.count == 0
              report.delete(customer_line)
            end

            # This product has been refunded
            refunded_product_codes.delete(product_code)

            # Update the totals
            customer_line[:OrderTotal] = (order_total + refund_line[:OrderTotal]).round(2)
            customer_line[:ItemSubtotal] = (item_subtotal + refund_line[:ItemSubtotal]).round(2)
            customer_line[:SalesTax] = (sales_tax + refund_line[:SalesTax]).round(2)
          end
        end
      end

      # Remove the refund line from the report
      if refunded_product_codes.count == 0
        report.delete(refund_line)
      end
    end

    report
  end

  def remove_shipping_product_codes(report)
    special_order_lines = report.select { |line| line[:ProductCode].include?(SPECIAL_ORDER_SKU) }
    special_order_lines.each do |special_order_line|
      product_codes = special_order_line[:ProductCode].split("|")
      special_order_product_code_index = product_codes.index(SPECIAL_ORDER_SKU)
      quantities = special_order_line[:Quantity].split("|")
      unit_prices = special_order_line[:UnitPrice].split("|")
      item_sales_taxes = special_order_line[:ItemSalesTax].split("|")

      # Update the totals
      special_order_line[:OrderTotal] = (special_order_line[:OrderTotal] - unit_prices[special_order_product_code_index].to_f).round(2)
      special_order_line[:ItemSubtotal] = (special_order_line[:ItemSubtotal] - unit_prices[special_order_product_code_index].to_f).round(2)
      special_order_line[:SalesTax] = (special_order_line[:SalesTax] - item_sales_taxes[special_order_product_code_index].to_f).round(2)

      # Remove the special order product from the product code list
      product_codes.delete_at(special_order_product_code_index)
      special_order_line[:ProductCode] = product_codes.join("|")

      # Remove the special order product from the quantities list
      quantities.delete_at(special_order_product_code_index)
      special_order_line[:Quantity] = quantities.join("|")

      # Remove the special order product from the unit prices list
      unit_prices.delete_at(special_order_product_code_index)
      special_order_line[:UnitPrice] = unit_prices.join("|")

      # Remove the special order product from the item sales taxes list
      item_sales_taxes.delete_at(special_order_product_code_index)
      special_order_line[:ItemSalesTax] = item_sales_taxes.join("|")
    end

    report
  end

  def is_bundle?(sku, products)
    products.each do |product|
      if product["sku"] == sku
        return product["type"] == "bundle"
      end
    end
  end

  def generate_report(job, sales)
    lines = []
    sales.each do |sale|
      lines << get_report_line(job, sale)
    end
    lines
  end

  def guest_customer_data(job)
    {
      "firstName" => "WTR",
      "lastName" => "GUEST - #{job.context["shop_name"]}",
      "Contact" => {
        "Emails" => {
          "ContactEmail" => [
            {
              "address" => CUSTOMER_ANONYMOUS_EMAIL,
              "useType" => "Primary"
            }
          ]
        },
        "Addresses" => {
          "ContactAddress" => [
            {
              "address1" => "100 Lake Hart Dr",
              "city" => "Orlando",
              "state" => "FL",
              "zip" => "32832"
            }
          ]
        }
      }
    }
  end

  def get_report_line(job, sale)
    # If the sale has no customer, use a guest customer
    sale["Customer"] ||= guest_customer_data(job)

    last_name = sale["Customer"]["lastName"].gsub(/\*\d+\*$/, "").strip.tr("*", "")
    tax_total = (sale["calcTax1"].to_f + sale["calcTax2"].to_f).round(2)
    item_subtotal = lsh.get_all_unit_prices(sale).map { |p| p.to_f }.sum.round(2)

    # Get shipping address from the event if it's not specified in the sale
    ship_address = if sale["ShipTo"].present?
      {
        "address1" => lsh.get_shipping_address(sale, "address1"),
        "address2" => "",
        "city" => lsh.get_shipping_address(sale, "city"),
        "state" => lsh.get_shipping_address(sale, "state"),
        "zip" => lsh.get_shipping_address(sale, "zip")
      }
    else
      job.context["event_address"]
    end

    {
      EventCode: job.event_code,
      SaleID: sale["saleID"],
      OrderDate: sale["timeStamp"].to_date.strftime("%Y-%m-%d"),
      Customer: "#{sale["Customer"]["firstName"]} #{sale["Customer"]["lastName"]}",
      FirstName: sale["Customer"]["firstName"],
      LastName: last_name,
      OrderTotal: sale["calcTotal"].to_f.round(2),
      ItemSubtotal: item_subtotal,
      SalesTax: tax_total,
      SpecialOrderFlag: lsh.get_special_order_flag(sale),
      TaxableOrderFlag: lsh.get_taxable_order_flag(sale),
      ProductCode: lsh.get_all_product_codes(sale).join("|"),
      Quantity: lsh.get_all_quantities(sale).join("|"),
      UnitPrice: lsh.get_all_unit_prices(sale).join("|"),
      ItemSalesTax: lsh.get_all_unit_taxes(sale, tax_total).join("|"),
      AddressLine1: lsh.get_address(sale, "address1"),
      AddressLine2: "",
      City: lsh.get_address(sale, "city"),
      State: lsh.get_address(sale, "state"),
      ZipPostal: lsh.get_address(sale, "zip"),
      Country: "US",
      ShipAddressLine1: ship_address["address1"],
      ShipAddressLine2: ship_address["address2"],
      ShipCity: ship_address["city"],
      ShipState: ship_address["state"],
      ShipZipPostal: ship_address["zip"],
      ShipCountry: "US",
      EmailAddress: lsh.get_email_addresses(sale)&.join("|") || CUSTOMER_ANONYMOUS_EMAIL,
      POSImportID: sale["saleID"]
    }
  end

  def put_sheet(job)
    report = job.context["report"]
    headers = [
      "EventCode",
      "SaleID",
      "OrderDate",
      "Customer",
      "FirstName",
      "LastName",
      "OrderTotal",
      "ItemSubtotal",
      "SalesTax",
      "SpecialOrderFlag",
      "TaxableOrderFlag",
      "ProductCode",
      "Quantity",
      "UnitPrice",
      "ItemSalesTax",
      "AddressLine1",
      "AddressLine2",
      "City",
      "State",
      "ZipPostal",
      "Country",
      "ShipAddressLine1",
      "ShipAddressLine2",
      "ShipCity",
      "ShipState",
      "ShipZipPostal",
      "ShipCountry",
      "EmailAddress",
      "POSImportID"
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
      major_dimension: "ROWS",
      values: rows
    }

    # make sure tab exists first
    response = sheets.get_spreadsheet(SHEET_ID)
    tab = response.sheets.find { |s| s.properties.title == job.event_code }

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
                fields: "gridProperties.frozenRowCount"
              }
            }
          }
        ]
      )
      begin
        sheets.batch_update_spreadsheet(SHEET_ID, request)
        response = sheets.get_spreadsheet(SHEET_ID)
        tab = response.sheets.find { |s| s.properties.title == job.event_code }
      rescue Google::Apis::ClientError => e
        throw e
      rescue Google::Apis::AuthorizationError => e
        Rails.logger.info "Authorization error: #{e.message}"
      rescue => e
        puRails.logger.infots "An error occurred: #{e.message}"
      end
    end
    if tab
      Rails.logger.info "Tab '#{job.event_code}' exists."
      sheets.clear_values(SHEET_ID, clear_range)
    end
    begin
      Rails.logger.info "Writing tab '#{job.event_code}'"
      sheets.update_spreadsheet_value(SHEET_ID, write_range, value_range_object, value_input_option: "RAW")
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
              fields: "gridProperties.frozenRowCount"
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
                  background_color: {red: 0.9, green: 0.9, blue: 0.9},
                  text_format: {bold: true}
                }
              },
              fields: "userEnteredFormat(backgroundColor,textFormat)"
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
                  type: "ONE_OF_LIST",
                  values: [
                    {user_entered_value: "IN REVIEW"},
                    {user_entered_value: "READY FOR WOO IMPORT"},
                    {user_entered_value: "PROCESSING"},
                    {user_entered_value: "IMPORTED TO WOO"},
                    {user_entered_value: "ERROR"}
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
                    {user_entered_value: {string_value: "Status"}},
                    {user_entered_value: {string_value: "IN REVIEW"}}
                  ]
                }
              ],
              start: {
                sheet_id: tab.properties.sheet_id,
                row_index: rows.count + 1,
                column_index: 0
              },
              fields: "userEnteredValue"
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
                    type: "TEXT_EQ",
                    values: [
                      {user_entered_value: "IN REVIEW"}
                    ]
                  },
                  format: {
                    background_color: {red: 0.9, green: 0.9, blue: 0.9} # Red for YES
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
                    type: "TEXT_EQ",
                    values: [
                      {user_entered_value: "READY FOR WOO IMPORT"}
                    ]
                  },
                  format: {
                    background_color: {red: 0.5, green: 1.0, blue: 0.5} # Green for NO
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
                    type: "TEXT_EQ",
                    values: [
                      {user_entered_value: "ERROR"}
                    ]
                  },
                  format: {
                    background_color: {red: 1.0, green: 0.5, blue: 0.5} # Green for NO
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
                    type: "TEXT_EQ",
                    values: [
                      {user_entered_value: "IMPORTED TO WOO"}
                    ]
                  },
                  format: {
                    background_color: {red: 0.8, green: 0.8, blue: 1.0} # Green for NO
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
                  background_color: {red: 0.9, green: 0.9, blue: 0.9},
                  text_format: {bold: true}
                }
              },
              fields: "userEnteredFormat(backgroundColor,textFormat)"
            }
          }
        ]
      )
      sheets.batch_update_spreadsheet(SHEET_ID, request)
      Rails.logger.info "Tab '#{job.event_code}' created successfully."
    rescue Google::Apis::ClientError => e
      throw e
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.info "Authorization error: #{e.message}"
    rescue => e
      Rails.logger.info "An error occurred: #{e.message}"
    end
  end

  def complete_job(job)
    # TODO
    # Get job record from the jobs table
    # Update the job status to COMPLETED
  end
end
