require "rails_helper"

describe WooImport do
  self.use_transactional_tests = false

  let(:wi) { WooImport.new }

  before do
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(nil)
  end

  it("it should initialize correctly") do
    expect(wi.woo).not_to be_nil
    expect(wi.sheets).not_to be_nil
    expect(wi.products).not_to be_nil
  end

  it "should start a new job if a WOO_REFRESH job is running" do
    allow(Job).to receive(:where).with(type: "WOO_REFRESH", status: :processing).and_return([double("job")])
    expect{wi.poll_jobs}.to have_enqueued_job(WoocommerceImportJob)
  end

  it "should not start a new job if a WOO_IMPORT job is running" do
    allow(Job).to receive(:where).with(type: "WOO_REFRESH", status: :processing).and_return([])
    allow(Job).to receive(:where).with(type: "WOO_IMPORT", status: :processing).and_return([double("job")])
    expect{wi.poll_jobs}.not_to have_enqueued_job(WoocommerceImportJob)
  end

  it "should return nil if no jobs to run are found" do
    allow(Job).to receive(:where).with(type: "WOO_REFRESH", status: :processing).and_return([])
    allow(Job).to receive(:where).with(type: "WOO_IMPORT", status: :processing).and_return([])
    allow(Job).to receive(:where).with(type: "WOO_IMPORT", status: [:created, :paused]).and_return([])
    expect(wi.poll_jobs).to be_nil
  end

  it "should mark all jobs as paused and handle them" do
    jobs = [double("job", id: 1), double("job", id: 2)]
    allow(Job).to receive(:where).with(type: "WOO_REFRESH", status: :processing).and_return([])
    allow(Job).to receive(:where).with(type: "WOO_IMPORT", status: :processing).and_return([])
    allow(Job).to receive(:where).with(type: "WOO_IMPORT", status: [:created, :paused]).and_return(jobs)
    jobs.each do |job|
      expect(job).to receive(:status_paused!)
      expect(wi).to receive(:handle_job).with(job)
    end
    wi.poll_jobs
  end

  it("it should get an array of objects from the sheet") do
    spreadsheet = double("spreadsheet", sheets: [Google::Apis::SheetsV4::Sheet.new(properties: double("properties", title: "WTR25CHS1"))])
    allow_any_instance_of(Google::Apis::SheetsV4::SheetsService).to receive(:get_spreadsheet).and_return(spreadsheet)
    allow_any_instance_of(Google::Apis::SheetsV4::SheetsService).to receive(:get_spreadsheet_values).and_return(Google::Apis::SheetsV4::ValueRange.new(values: [["FakeData", "READY FOR WOO IMPORT"], ["FakeData", "READY FOR WOO IMPORT"], ["FakeData", "READY FOR WOO IMPORT"]]))

    job = wi.create_job
    job.event_code = "WTR25CHS1"
    rows = wi.get_spreadsheet job
    expect(rows.count).to be > 0
  end

  it("it should build a item list from a row") do
    rows = [["ProductCode", "Quantity", "ItemSalesTax", "UnitPrice"], ["BKP21550|BKP20074|BKH20397|BKP21762|BKP21787", "2|1|2|1|1", "0.0|0.0|0.0|0.0|0.0", "26.64|13.32|26.64|13.32|8.99"]]

    job = wi.create_job
    job.event_code = "WTR25CHS1"
    wi.build_column_hash rows[0]
    row = rows[1]
    items = wi.get_row_items row
    expected = [{sku: "BKP21550", quantity: 2, subtotal_tax: "0.0", subtotal: "26.64"}, {sku: "BKP20074", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH20397", quantity: 2, subtotal_tax: "0.0", subtotal: "26.64"}, {sku: "BKP21762", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP21787", quantity: 1, subtotal_tax: "0.0", subtotal: "8.99"}]
    items.each_with_index do |item, index|
      expect(item[:sku]).to eq expected[index][:sku]
      expect(item[:quantity]).to eq expected[index][:quantity]
      expect(item[:subtotal_tax]).to eq expected[index][:subtotal_tax]
      expect(item[:subtotal]).to eq expected[index][:subtotal]
    end
  end

  it("it should build a list of objects from a sheet") do
    rows = [["EventCode", "SaleID", "OrderDate", "Customer", "FirstName", "LastName", "OrderTotal", "ItemSubtotal", "SalesTax", "SpecialOrderFlag", "TaxableOrderFlag", "ProductCode", "Quantity", "UnitPrice", "ItemSalesTax", "AddressLine1", "AddressLine2", "City", "State", "ZipPostal", "Country", "ShipAddressLine1", "ShipAddressLine2", "ShipCity", "ShipState", "ShipZipPostal", "ShipCountry", "EmailAddress", "POSImportID"],
      ["WTR25CHS1", "249582", "2021-06-25 12:00:00", "Teena Hoover", "Teena", "Hoover", "14.99", "14.99", "0.0", "N", "Y", "APP21574", "1", "14.99", "0.0", "119 Vista Lane", "", "Fairfield Bay", "Arkansas", "72088", "US", "119 Vista Lane", "", "Fairfield Bay", "Arkansas", "72088", "US", "trhoover@familylife.com", "POS import"],
      ["WTR25CHS1", "249608", "2021-06-25 12:00:00", "Mark Snyder", "Mark", "Snyder", "9.99", "9.99", "0.0", "N", "Y", "MSC21692", "1", "9.99", "0.0", "3249 Ian Patrick", "", "Kannapolis", "NC", "28083", "US", "3249 Ian Patrick", "", "Kannapolis", "NC", "28083", "US", "mjsnyder7@icloud.com", "POS import"]]
    event_code = "WTR25CHS1"

    objects = wi.build_woo_list rows, event_code
    expected = [{status: "completed", billing: {first_name: "Teena", last_name: "Hoover", address_1: "119 Vista Lane", address_2: "", city: "Fairfield Bay", state: "Arkansas", postcode: "72088", country: "US", email: "trhoover@familylife.com"}, line_items: [{sku: "APP21574", quantity: 1, subtotal_tax: "0.0", subtotal: "14.99", total: "14.99", total_tax: "0.0"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "WTR25CHS1-249582"}, {key: "event_code", value: "WTR25CHS1"}, {key: "transaction_notes", value: "249582"}], shipping: {address_1: "119 Vista Lane", address_2: "", city: "Fairfield Bay", country: "US", email: "trhoover@familylife.com", first_name: "Teena", last_name: "Hoover", postcode: "72088", state: "Arkansas"}}, {status: "completed", billing: {first_name: "Mark", last_name: "Snyder", address_1: "3249 Ian Patrick", address_2: "", city: "Kannapolis", state: "NC", postcode: "28083", country: "US", email: "mjsnyder7@icloud.com"}, line_items: [{sku: "MSC21692", quantity: 1, subtotal_tax: "0.0", subtotal: "9.99", total: "9.99", total_tax: "0.0"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "WTR25CHS1-249608"}, {key: "event_code", value: "WTR25CHS1"}, {key: "transaction_notes", value: "249608"}], shipping: {address_1: "3249 Ian Patrick", address_2: "", city: "Kannapolis", country: "US", email: "mjsnyder7@icloud.com", first_name: "Mark", last_name: "Snyder", postcode: "28083", state: "NC"}}]
    expect(objects).to eq expected
  end

  it("it should be able to send a batch of sales to woo") do
    rows = [["EventCode", "SaleID", "OrderDate", "Customer", "FirstName", "LastName", "OrderTotal", "ItemSubtotal", "SalesTax", "SpecialOrderFlag", "TaxableOrderFlag", "ProductCode", "Quantity", "UnitPrice", "ItemSalesTax", "AddressLine1", "AddressLine2", "City", "State", "ZipPostal", "Country", "ShipAddressLine1", "ShipAddressLine2", "ShipCity", "ShipState", "ShipZipPostal", "ShipCountry", "EmailAddress", "POSImportID"],
      ["WTR25CHS1", "249582", "2021-06-25 12:00:00", "Teena Hoover", "Teena", "Hoover", "14.99", "14.99", "0.0", "N", "Y", "APP21574", "1", "14.99", "0.0", "119 Vista Lane", "", "Fairfield Bay", "Arkansas", "72088", "US", "119 Vista Lane", "", "Fairfield Bay", "Arkansas", "72088", "US", "trhoover@familylife.com", "POS import"],
      ["WTR25CHS1", "249608", "2021-06-25 12:00:00", "Mark Snyder", "Mark", "Snyder", "9.99", "9.99", "0.0", "N", "Y", "MSC21692", "1", "9.99", "0.0", "3249 Ian Patrick", "", "Kannapolis", "NC", "28083", "US", "3249 Ian Patrick", "", "Kannapolis", "NC", "28083", "US", "mjsnyder7@icloud.com", "POS import"]]
    event_code = "WTR25CHS1"

    expect_any_instance_of(WooCommerce::API).to receive(:post).exactly(2).times.and_return({"id" => 1234})

    job = wi.create_job
    objects = wi.build_woo_list rows, event_code
    list = wi.send_to_woo objects, job
    list.each do |order|
      expect(order["id"].is_a?(Integer)).to be true
    end
  end
end
