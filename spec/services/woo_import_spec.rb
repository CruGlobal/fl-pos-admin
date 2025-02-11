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

  it("it should get an array of objects from the sheet") do
    spreadsheet = double("spreadsheet", sheets: [Google::Apis::SheetsV4::Sheet.new(properties: double("properties", title: "WTR25CHS1"))])
    allow_any_instance_of(Google::Apis::SheetsV4::SheetsService).to receive(:get_spreadsheet).and_return(spreadsheet)
    allow_any_instance_of(Google::Apis::SheetsV4::SheetsService).to receive(:get_spreadsheet_values).and_return(Google::Apis::SheetsV4::ValueRange.new(values: [["FakeData", "READY FOR WOO IMPORT"], ["FakeData", "READY FOR WOO IMPORT"], ["FakeData", "READY FOR WOO IMPORT"]]))

    job = wi.create_job
    job.event_code = "WTR25CHS1"
    rows = wi.get_spreadsheet job
    expect(rows.count).to be > 0
  end

  xit("it should build a item list from a row") do
    job = wi.create_job
    job.event_code = "WTR25CHS1"
    rows = wi.get_spreadsheet job
    row = rows[4]
    items = wi.get_row_items row
    expected = [{sku: "BKP21550", quantity: 2, subtotal_tax: "0.0", subtotal: "26.64"}, {sku: "BKP20074", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH20397", quantity: 2, subtotal_tax: "0.0", subtotal: "26.64"}, {sku: "BKP21762", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP21787", quantity: 1, subtotal_tax: "0.0", subtotal: "8.99"}]
    items.each_with_index do |item, index|
      expect(item[:sku]).to eq expected[index][:sku]
      expect(item[:quantity]).to eq expected[index][:quantity]
      expect(item[:subtotal_tax]).to eq expected[index][:subtotal_tax]
      expect(item[:subtotal]).to eq expected[index][:subtotal]
    end
  end

  xit("it should build a list of objects from a sheet") do
    job = wi.create_job
    job.event_code = "WTR25CHS1"
    rows = wi.get_spreadsheet job
    objects = wi.build_woo_list rows
    expected = [{status: "completed", billing: {first_name: "Teena", last_name: "Hoover", address_1: "119 Vista Lane", address_2: "", city: "Fairfield Bay", state: "Arkansas", postcode: "72088", country: "US", email: "trhoover@familylife.com"}, line_items: [{sku: "APP21574", quantity: 1, subtotal_tax: "0.0", subtotal: "14.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249582"}, {key: "event_code", value: 249582}, {key: "transaction_notes", value: 249582}]}, {status: "completed", billing: {first_name: "Mark", last_name: "Snyder", address_1: "3249 Ian Patrick", address_2: "", city: "Kannapolis", state: "NC", postcode: "28083", country: "US", email: "mjsnyder7@icloud.com"}, line_items: [{sku: "MSC21692", quantity: 1, subtotal_tax: "0.0", subtotal: "9.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249608"}, {key: "event_code", value: 249608}, {key: "transaction_notes", value: 249608}]}, {status: "completed", billing: {first_name: "Bradley", last_name: "Clay", address_1: "33543 Pennbrooke Pkwy", address_2: "", city: "Leesburg", state: "FL", postcode: "34748", country: "US", email: "bradclay2024@gmail.com"}, line_items: [{sku: "MSC21692", quantity: 1, subtotal_tax: "0.0", subtotal: "9.99"}, {sku: "BKP21307", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKP21308", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "KIT21859", quantity: 1, subtotal_tax: "0.0", subtotal: "59.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249611"}, {key: "event_code", value: 249611}, {key: "transaction_notes", value: 249611}]}, {status: "completed", billing: {first_name: "Ash", last_name: "Sturgeon", address_1: "242 West Columbia Ave", address_2: "", city: "Batesburg", state: "SC", postcode: "29006", country: "US", email: "ashsturgeon@gmail.com"}, line_items: [{sku: "APP21572", quantity: 1, subtotal_tax: "0.0", subtotal: "24.99"}, {sku: "BKP21674", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH21586", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP12001", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP19056", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP20074", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH21610", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249612"}, {key: "event_code", value: 249612}, {key: "transaction_notes", value: 249612}]}, {status: "completed", billing: {first_name: "Franklin", last_name: "Wagner", address_1: "619 Turrentine Church Road", address_2: "", city: "Mocksville", state: "NC", postcode: "27028", country: "US", email: "fandcwag@gmail.com"}, line_items: [{sku: "BKP21550", quantity: 2, subtotal_tax: "0.0", subtotal: "26.64"}, {sku: "BKP20074", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH20397", quantity: 2, subtotal_tax: "0.0", subtotal: "26.64"}, {sku: "BKP21762", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP21787", quantity: 1, subtotal_tax: "0.0", subtotal: "8.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249613"}, {key: "event_code", value: 249613}, {key: "transaction_notes", value: 249613}]}, {status: "completed", billing: {first_name: "Jennifer", last_name: "Cater", address_1: "825 Bellview Way", address_2: "", city: "Seneca", state: "SC", postcode: "29678", country: "US", email: "jenniferdcater92@gmail.com"}, line_items: [{sku: "BKP13003", quantity: 1, subtotal_tax: "0.0", subtotal: "39.99"}, {sku: "APP21562", quantity: 1, subtotal_tax: "0.0", subtotal: "19.99"}, {sku: "APP21563", quantity: 1, subtotal_tax: "0.0", subtotal: "19.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249614"}, {key: "event_code", value: 249614}, {key: "transaction_notes", value: 249614}]}, {status: "completed", billing: {first_name: "David", last_name: "Kauffman", address_1: "6270 Foster Rd", address_2: "", city: "Woodleaf", state: "NC", postcode: "27054-9640", country: "US", email: "dak6519@gmail.com"}, line_items: [{sku: "APP21563", quantity: 1, subtotal_tax: "0.0", subtotal: "19.99"}, {sku: "APP21564", quantity: 1, subtotal_tax: "0.0", subtotal: "19.99"}, {sku: "BKP21307", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKP21308", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKP20074", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP21764", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH21586", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "RPK20929", quantity: 1, subtotal_tax: "0.0", subtotal: "39.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249615"}, {key: "event_code", value: 249615}, {key: "transaction_notes", value: 249615}]}, {status: "completed", billing: {first_name: "Amanda", last_name: "Harrell", address_1: "1718 Meadowbrook Ln W", address_2: "", city: "Wilson", state: "NC", postcode: "27893", country: "US", email: "amandah521@outlook.com"}, line_items: [{sku: "BKP21307", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKP19056", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH21610", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP20588", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "MSC21692", quantity: 1, subtotal_tax: "0.0", subtotal: "9.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249616"}, {key: "event_code", value: 249616}, {key: "transaction_notes", value: 249616}]}, {status: "completed", billing: {first_name: "Rob", last_name: "Sink", address_1: "13640 Gurney Path", address_2: "", city: "Apple Valley", state: "MN", postcode: "55124", country: "US", email: "rob.sink21@gmail.com"}, line_items: [{sku: "KIT21859", quantity: 1, subtotal_tax: "0.0", subtotal: "59.99"}, {sku: "BKP19500", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH20397", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP12001", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249617"}, {key: "event_code", value: 249617}, {key: "transaction_notes", value: 249617}]}, {status: "completed", billing: {first_name: "Matt", last_name: "McFarland", address_1: "79 Creekside Dr", address_2: "", city: "Summerville", state: "SC", postcode: "29485", country: "US", email: "mfmcfarland96@gmail.com"}, line_items: [{sku: "MSC21692", quantity: 1, subtotal_tax: "0.0", subtotal: "9.99"}, {sku: "BKP21308", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKP21307", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKP21127", quantity: 1, subtotal_tax: "0.0", subtotal: "16.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249618"}, {key: "event_code", value: 249618}, {key: "transaction_notes", value: 249618}]}, {status: "completed", billing: {first_name: "Chaston", last_name: "Bullock", address_1: "1939 California Road NW", address_2: "", city: "Brookhaven", state: "MS", postcode: "39601", country: "US", email: "cbullock@co.lincoln.ms.us"}, line_items: [{sku: "APP21563", quantity: 1, subtotal_tax: "0.0", subtotal: "19.99"}, {sku: "APP21572", quantity: 1, subtotal_tax: "0.0", subtotal: "24.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249619"}, {key: "event_code", value: 249619}, {key: "transaction_notes", value: 249619}]}, {status: "completed", billing: {first_name: "Linda", last_name: "Kauffman", address_1: "6270 Foster Rd", address_2: "", city: "Woodleaf", state: "NC", postcode: "27054-9640", country: "US", email: "dkslinda@gmail.com"}, line_items: [{sku: "MSC21692", quantity: 1, subtotal_tax: "0.0", subtotal: "9.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249620"}, {key: "event_code", value: 249620}, {key: "transaction_notes", value: 249620}]}, {status: "completed", billing: {first_name: "Kaylee", last_name: "Davis", address_1: "967 Pinbrook Drive", address_2: "", city: "Lawrenceville", state: "GA", postcode: "30043", country: "US", email: "kayofthelee37@hotmail.com"}, line_items: [{sku: "BKP21764", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP21761", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP21550", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP21307", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKP21308", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249621"}, {key: "event_code", value: 249621}, {key: "transaction_notes", value: 249621}]}, {status: "completed", billing: {first_name: "Pete", last_name: "Kluck", address_1: "6310 Nikki Ln", address_2: "", city: "Tampa", state: "FL", postcode: "33625", country: "US", email: "pete_kluck@wycliffe.org"}, line_items: [{sku: "BKP21308", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKP21307", quantity: 1, subtotal_tax: "0.0", subtotal: "4.99"}, {sku: "BKH20397", quantity: 1, subtotal_tax: "0.0", subtotal: "19.99"}, {sku: "BKH20397", quantity: 3, subtotal_tax: "0.0", subtotal: "39.96"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249622"}, {key: "event_code", value: 249622}, {key: "transaction_notes", value: 249622}]}, {status: "completed", billing: {first_name: "Noah", last_name: "Ingold", address_1: "1022 Rising View Way", address_2: "", city: "Asheboro", state: "NC", postcode: "27205", country: "US", email: "niasheboro@gmail.com"}, line_items: [{sku: "BKP20074", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP21348", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH20397", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249623"}, {key: "event_code", value: 249623}, {key: "transaction_notes", value: 249623}]}, {status: "completed", billing: {first_name: "Rodney", last_name: "Lawless", address_1: "248 Calm Water Way", address_2: "", city: "Summerville", state: "SC", postcode: "29486", country: "US", email: "rodlawless1@gmail.com"}, line_items: [{sku: "MSC21692", quantity: 3, subtotal_tax: "0.0", subtotal: "29.97"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249625"}, {key: "event_code", value: 249625}, {key: "transaction_notes", value: 249625}]}, {status: "completed", billing: {first_name: "Brittany", last_name: "Bailey", address_1: "2092 Longwood Drive", address_2: "", city: "Creedmoor", state: "NC", postcode: "27522", country: "US", email: "williamsbm95@gmail.com"}, line_items: [{sku: "BKP13003", quantity: 1, subtotal_tax: "0.0", subtotal: "39.99"}, {sku: "APP21575", quantity: 1, subtotal_tax: "0.0", subtotal: "24.99"}, {sku: "BKP19056", quantity: 1, subtotal_tax: "0.0", subtotal: "14.99"}, {sku: "BKP21764", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKP20074", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}, {sku: "BKH20397", quantity: 1, subtotal_tax: "0.0", subtotal: "13.32"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249626"}, {key: "event_code", value: 249626}, {key: "transaction_notes", value: 249626}]}, {status: "completed", billing: {first_name: "Chase", last_name: "Catledge", address_1: "1047 Four Boys Aly", address_2: "", city: "Richburg", state: "SC", postcode: "29729", country: "US", email: "pastorchasec@gmail.com"}, line_items: [{sku: "APP21562", quantity: 1, subtotal_tax: "0.0", subtotal: "19.99"}, {sku: "APP21563", quantity: 1, subtotal_tax: "0.0", subtotal: "19.99"}], meta_data: [{key: "cru_order_origin", value: "POS import"}, {key: "event_transaction", value: "249627"}, {key: "event_code", value: 249627}, {key: "transaction_notes", value: 249627}], shipping: {first_name: "Chase", last_name: "Catledge*23932912*", address_1: "70 CO RD 27", address_2: "", city: "Monte Vista", state: "CO", postcode: 81144, country: "US", email: "pastorchasec@gmail.com"}}]
    actual = objects.to_json
    expected = expected.to_json
    expect(actual).to eq expected
  end

  xit("it should be able to send a batch of sales to woo") do
    job = wi.create_job
    job.event_code = "WTR25CHS1"
    rows = wi.get_spreadsheet job
    # get only the first two rows to test with
    rows = rows[0..1]
    objects = wi.build_woo_list rows
    list = wi.send_to_woo objects, job
    list.each do |order|
      expect(order["id"].is_a?(Integer)).to be true
    end
  end

  xit("should be able to set the ready status of a sheet") do
    wi.set_ready_status("WTR25CHS1", 21, "ERROR")
    response = wi.sheets.get_spreadsheet(ENV["GOOGLE_SHEET_ID"])
    response.sheets.select do |s|
      if s.properties.title == "WTR25CHS1"
        range = "WTR25CHS1!A21:B"
        response = wi.sheets.get_spreadsheet_values(SHEET_ID, range, value_render_option: "UNFORMATTED_VALUE")
        values = response.values
        expect(values[0][1]).to eq("ERROR")
      end
    end
  end
end
