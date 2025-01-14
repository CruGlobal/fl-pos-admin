require "rails_helper"
require "json"

describe LSExtract do
  # set global lightspeed import service
  lsi = LSExtract.new
  lsh = LightspeedApiHelper.new
  file = File.read("#{Rails.root}/spec/services/fixtures/sales_formatted.json")
  example_sales = JSON.parse(file)
  # woo cache must be populated first
  woo = WooRefresh.new
  if woo.latest_refresh_timestamp.nil? || woo.latest_refresh_timestamp < 1.day.ago
    puts "Woo cache is stale, refreshing..."
    woo.handle_job woo.create_job
  end

  it("should initialize a new job") do
    context = lsi.create_job 16, "2024-12-01", "2024-12-31"
    expect(context[:event_code]).not_to be_nil
  end

  it("should get products from woo cache") do
    products = lsi.get_products 10
    expect(products.count).to be == 10

    products = lsi.get_products
    expect(products.count).to be > 400
  end

  it("should strip sales data to only the essentials") do
    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    sales = lsh.get_sales job, 16, "2024-12-06", "2024-12-07"
    sales = lsh.strip_to_named_fields(sales, LightspeedSaleSchema.fields_to_keep)
    expect(sales.first.keys.count).to be == 11
  end

  it("should get all product codes") do
    codes = lsh.get_all_product_codes(example_sales[2])
    actual = codes.join("|")
    expected = "MSC21692|BKP21307|BKP21308|KIT21859"
    expect(actual).to eq(expected)
  end

  it("should get all product quantities") do
    codes = lsh.get_all_quantities(example_sales[2])
    actual = codes.join("|")
    expected = "1|1|1|1"
    expect(actual).to eq(expected)
  end

  it("should get all unit prices") do
    codes = lsh.get_all_unit_prices(example_sales[2])
    actual = codes.join("|")
    expected = "9.99|4.99|4.99|59.99"
    expect(actual).to eq(expected)
  end

  it("should get all unit taxes") do
    codes = lsh.get_all_unit_taxes(example_sales[2])
    actual = codes.join("|")
    expected = "0.0|0.0|0.0|0.0"
    expect(actual).to eq(expected)
  end

  it("should get the taxable order flag") do
    flag = lsh.get_taxable_order_flag(example_sales[2])
    expected = "Y"
    expect(flag).to eq(expected)
  end

  it("should get the special order flag") do
    flag = lsh.get_special_order_flag(example_sales[0])
    expected = "Y"
    expect(flag).to eq(expected)
    flag = lsh.get_special_order_flag(example_sales[2])
    expected = "N"
    expect(flag).to eq(expected)
  end

  it("should get an address field") do
    sale = example_sales[2]
    sale = lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep)
    val = lsh.get_address(sale, "address1")
    expect(val).to be == "33543 Pennbrooke Pkwy"

    val = lsh.get_address(sale, "foo")
    expect(val).to be nil
  end

  it("should get email addresses") do
    sale = example_sales[2]
    sale = lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep)
    val = lsh.get_email_addresses(sale).join("|")
    expect(val).to be == "bradclay2024@gmail.com"
  end

  it("should get a shipping customers") do
    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    customers = lsh.get_shipping_customers(job, example_sales)
    expect(customers.count).to be == 2
  end

  it("should be able to get a shipping address field") do
    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    sale = example_sales[1]
    sale = lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep)
    customers = lsh.get_shipping_customers(job, example_sales)
    val = lsh.get_shipping_address(sale, customers, "address1")
    expect(val).to be == "119 Vista Lane"

    val = lsh.get_address(sale, "foo")
    expect(val).to be nil
  end

  it("should get a report line") do
    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    sale = example_sales[1]
    sale = lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep)
    customers = lsh.get_shipping_customers(job, example_sales)
    products = lsi.get_products
    line = lsi.get_report_line(job, sale, products, customers)
    expected = '{
  "EventCode": "WTR25CHS1",
  "SaleID": 249608,
  "OrderDate": "2024-12-06",
  "Customer": "Mark Snyder**",
  "FirstName": "Mark",
  "LastName": "Snyder**",
  "OrderTotal": "9.99",
  "ItemSubtotal": "9.99",
  "SalesTax": 0.0,
  "SpecialOrderFlag": "N",
  "TaxableOrderFlag": "Y",
  "ProductCode": "MSC21692",
  "Quantity": "1",
  "UnitPrice": "9.99",
  "ItemSalesTax": "0.0",
  "AddressLine1": "3249 Ian Patrick",
  "AddressLine2": "",
  "City": "Kannapolis",
  "State": "NC",
  "ZipPostal": "28083",
  "Country": "US",
  "ShipAddressLine1": "119 Vista Lane",
  "ShipAddressLine2": "",
  "ShipCity": "Fairfield Bay",
  "ShipState": "Arkansas",
  "ShipZipPostal": "72088",
  "ShipCountry": "US",
  "EmailAddress": "mjsnyder7@icloud.com",
  "POSImportID": 249608
}'
    expect(JSON.pretty_generate(line)).to eq(expected)
    puts line.inspect
  end

  it("should produce a full report") do
    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    lsi.handle_job job
    job.reload
    expected = '{"City":"Fairfield Bay","State":"Arkansas","SaleID":249582,"Country":"US","Customer":"Teena Hoover *10006483*","LastName":"Hoover *10006483*","Quantity":"1","SalesTax":0.0,"ShipCity":null,"EventCode":"WTR25CHS1","FirstName":"Teena","OrderDate":"2024-12-06","ShipState":null,"UnitPrice":"14.99","ZipPostal":"72088","OrderTotal":"14.99","POSImportID":249582,"ProductCode":"APP21574","ShipCountry":"US","AddressLine1":"119 Vista Lane","AddressLine2":"","EmailAddress":"trhoover@familylife.com","ItemSalesTax":"0.0","ItemSubtotal":"24.99","ShipZipPostal":null,"ShipAddressLine1":null,"ShipAddressLine2":"","SpecialOrderFlag":"N","TaxableOrderFlag":"Y"}'
    expect(job.context["report"].first.to_json).to eq(expected)
  end

  it("should write the report to the spreadsheet", focus: true) do
    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    lsi.handle_job job
    job.reload
    response = lsi.put_sheet job
    puts "RESPONSE: #{response.inspect}"
    puts "DONE"
  end
end
