require "rails_helper"
require "json"

describe LSExtract do
  # set global lightspeed import service
  let(:lsi) { LSExtract.new }
  let(:lsh) { LightspeedApiHelper.new }
  let(:example_sales) { JSON.parse(File.read("#{Rails.root}/spec/fixtures/sales_formatted.json")) }

  before do
    shop = double("shop")
    allow_any_instance_of(LightspeedApiHelper).to receive(:find_shop).and_return(shop)
    allow(shop).to receive("Contact").and_return({"custom" => "random_event_code"})

    create_list(:woo_product, 401)

    allow_any_instance_of(WooRefresh).to receive(:latest_refresh_timestamp).and_return(1.hour.ago)
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(nil)
    LightspeedStubHelpers.stub_lightspeed_account_request
  end

  it("should get a report line with shipping") do
    job = lsi.create_job 66, "2025-01-30", "2025-02-05"
    sales = JSON.parse(File.read("#{Rails.root}/spec/fixtures/2025.02.05.grand_rapids.json"))
    sale = sales.find { |sale| sale["saleID"] == 250210 }
    sale = lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep)
    line = lsi.get_report_line(job, sale)
    expect(line[:ShipAddressLine1]).to eq("550 Riley St.")
    expect(line[:ShipCity]).to eq("Lansing")
    expect(line[:ShipState]).to eq("MI")
    expect(line[:ShipZipPostal]).to eq("48910")
  end

  it("should generate an entire report with shipping in places where it needs it") do
    job = lsi.create_job 66, "2025-01-30", "2025-02-05"
    sales = JSON.parse(File.read("#{Rails.root}/spec/fixtures/2025.02.05.grand_rapids.json"))
    report = lsi.generate_report(job, sales)
    report = lsi.process_report(report)
    line1 = report.find { |line| line[:SaleID] == 250210 }
    line2 = report.find { |line| line[:SaleID] == 250212 }
    expect(line1[:ShipAddressLine1]).to eq("550 Riley St.")
    expect(line2[:ShipAddressLine1]).to be_nil
  end

  it("should calculate unit prices properly") do
    lsi.create_job 66, "2025-01-30", "2025-02-05"
    # get sales and JSON pretty print them to the file
    # sales = lsh.get_sales job, 66, "2025-01-30", "2025-02-05"
    # File.write("#{Rails.root}/spec/fixtures/2025.02.05.grand_rapids.json", sales.to_json)
    sales = JSON.parse(File.read("#{Rails.root}/spec/fixtures/2025.02.05.grand_rapids.json"))
    context = {}
    context["sales"] = sales
    context["sales"] = context["sales"].map { |sale| lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep) }

    count = 0

    # Visual test for values
    sales.each do |sale|
      # add up al of the unit prices
      count += 1
      next if count < 146

      break if count > 146

      tax_total = (sale["calcTax1"].to_f + sale["calcTax2"].to_f).round(2)
      item_tax_total = lsh.get_all_unit_taxes(sale, tax_total).sum.to_f.round(2)

      order_total = sale["calcTotal"].to_f.round(2)
      item_total = (lsh.get_all_unit_prices(sale).sum.to_f.round(2) + tax_total.to_f.round(2)).round(2)

      # puts "Sale ID: #{sale['saleID']}"
      # puts "Special Order: " + lsh.get_special_order_flag(sale)
      # puts 'Tax Total: ' + tax_total.to_s
      # puts 'Tax Items: ' + item_tax_total.to_s
      # puts 'Tax Difference: ' + (item_tax_total - tax_total).to_s
      # puts ''
      # puts 'Order Total: ' + order_total.to_s
      # puts 'Item Total: ' + item_total.to_s
      # puts 'Item Difference: ' + (item_total - order_total).to_s

      expect(item_tax_total).to eq(tax_total)
      expect(order_total).to eq(item_total)
    end
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
    sale = {"saleID" => "249582", "timeStamp" => "2024-12-06T15:23:49+00:00", "discountPercent" => "0", "completed" => "true", "archived" => "false", "voided" => "false", "enablePromotions" => "true", "isTaxInclusive" => "false", "tipEnabled" => "false", "createTime" => "2024-12-06T15:21:49+00:00", "updateTime" => "2024-12-06T15:23:50+00:00", "completeTime" => "2024-12-06T15:23:49+00:00", "referenceNumber" => "", "referenceNumberSource" => "", "tax1Rate" => "0", "tax2Rate" => "0", "change" => "0", "receiptPreference" => "printed", "displayableSubtotal" => "24.99", "ticketNumber" => "220000249582", "calcDiscount" => "10", "calcTotal" => "14.99", "calcSubtotal" => "24.99", "calcTaxable" => "0", "calcNonTaxable" => "14.99", "calcAvgCost" => "0", "calcFIFOCost" => "0", "calcTax1" => "0", "calcTax2" => "0", "calcPayments" => "14.99", "calcTips" => "0", "calcItemFees" => "0", "total" => "14.99", "totalDue" => "14.99", "displayableTotal" => "14.99", "balance" => "0", "customerID" => "1064752", "discountID" => "0", "employeeID" => "378", "quoteID" => "0", "registerID" => "28", "shipToID" => "0", "shopID" => "16", "taxCategoryID" => "0", "tipEmployeeID" => "0", "Customer" => {"customerID" => "1064752", "firstName" => "Teena", "lastName" => "Hoover *10006483*", "archived" => "false", "title" => "", "company" => "", "companyRegistrationNumber" => "", "vatNumber" => "", "createTime" => "2024-08-31T00:06:41+00:00", "timeStamp" => "2024-12-07T19:28:12+00:00", "contactID" => "1120867", "creditAccountID" => "641", "customerTypeID" => "48", "discountID" => "0", "employeeID" => "0", "noteID" => "29593", "taxCategoryID" => "0", "measurementID" => "0", "Contact" => {"contactID" => "1120867", "custom" => "Staff", "noEmail" => "true", "noPhone" => "true", "noMail" => "true", "timeStamp" => "2024-12-07T19:28:12+00:00", "Addresses" => {"ContactAddress" => {"address1" => "119 Vista Lane", "city" => "Fairfield Bay", "state" => "Arkansas", "zip" => "72088"}}, "Phones" => {"ContactPhone" => {"number" => "501-658-9928", "useType" => "Mobile"}}, "Emails" => {"ContactEmail" => {"address" => "trhoover@familylife.com", "useType" => "Primary"}}, "Websites" => ""}}, "SaleLines" => {"SaleLine" => {"saleLineID" => "251030", "createTime" => "2024-12-06T15:23:10+00:00", "timeStamp" => "2024-12-06T15:23:49+00:00", "unitQuantity" => "1", "unitPrice" => "24.99", "normalUnitPrice" => "0", "discountAmount" => "0", "discountPercent" => "0.4", "avgCost" => "0", "fifoCost" => "0", "tax" => "true", "tax1Rate" => "0", "tax2Rate" => "0", "isLayaway" => "false", "isWorkorder" => "false", "isSpecialOrder" => "false", "displayableSubtotal" => "14.99", "displayableUnitPrice" => "24.99", "lineType" => "", "calcLineDiscount" => "10", "calcTransactionDiscount" => "0", "calcTotal" => "14.99", "calcSubtotal" => "24.99", "calcTax1" => "0", "calcTax2" => "0", "taxClassID" => "6", "customerID" => "0", "discountID" => "34", "employeeID" => "378", "itemID" => "7363", "noteID" => "0", "parentSaleLineID" => "0", "shopID" => "16", "saleID" => "249582", "itemFeeID" => "0", "TaxClass" => {"taxClassID" => "6", "name" => "Clothing", "classType" => "item"}, "Discount" => {"discountID" => "34", "name" => "CRU Staff - 40%", "discountAmount" => "0", "discountPercent" => "0.4", "requireCustomer" => "true", "archived" => "false", "sourceID" => "0", "createTime" => "2020-03-04T12:39:31+00:00", "timeStamp" => "2014-04-03T20:15:31+00:00"}, "Item" => {"itemID" => "7363", "systemSku" => "210000007375", "defaultCost" => "0", "avgCost" => "0", "discountable" => "true", "tax" => "true", "archived" => "false", "itemType" => "default", "laborDurationMinutes" => "0", "serialized" => "false", "description" => "WTR Worth It Hoodie - LARGE *APP21574*", "modelYear" => "0", "upc" => "", "ean" => "9785001028673", "customSku" => "APP21574", "manufacturerSku" => "", "createTime" => "2022-12-12T22:29:20+00:00", "timeStamp" => "2024-10-24T20:19:19+00:00", "publishToEcom" => "false", "categoryID" => "0", "taxClassID" => "6", "departmentID" => "0", "itemMatrixID" => "0", "itemAttributesID" => "0", "manufacturerID" => "0", "noteID" => "13608", "seasonID" => "0", "defaultVendorID" => "0", "Prices" => {"ItemPrice" => [{"amount" => "24.99", "useTypeID" => "1", "useType" => "Default"}, {"amount" => "24.99", "useTypeID" => "2", "useType" => "MSRP"}]}}}}, "SalePayments" => {"SalePayment" => {"salePaymentID" => "92215", "amount" => "14.99", "tipAmount" => "0", "createTime" => "2024-12-06T15:23:34+00:00", "archived" => "false", "remoteReference" => "", "paymentID" => "f94edd55-bcbc-485a-9c4a-5640eb05543c", "saleID" => "249582", "paymentTypeID" => "3", "ccChargeID" => "0", "refPaymentID" => "0", "registerID" => "28", "employeeID" => "378", "creditAccountID" => "0", "PaymentType" => {"paymentTypeID" => "3", "code" => "Credit Card", "name" => "Credit Card", "requireCustomer" => "false", "archived" => "false", "internalReserved" => "false", "type" => "credit card", "channel" => "", "refundAsPaymentTypeID" => "3"}}}, "MetaData" => {"tipOption1" => "10", "tipOption2" => "15", "tipOption3" => "20"}, "taxTotal" => "0"}
    sales = lsh.strip_to_named_fields([sale], LightspeedSaleSchema.fields_to_keep)
    expect(sales.first.keys.count).to be == 12
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
    codes = lsh.get_all_unit_taxes(example_sales[2], example_sales[2]["calcTaxable"].to_f)
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

  it("should be able to get a shipping address field") do
    sale = example_sales[1]
    sale = lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep)
    val = lsh.get_shipping_address(sale, "address1")
    expect(val).to be == "119 Vista Lane"

    val = lsh.get_address(sale, "foo")
    expect(val).to be nil
  end

  it("should get a report line") do
    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    sale = example_sales[1]
    sale = lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep)
    line = lsi.get_report_line(job, sale)
    expected = '{
  "EventCode": "random_event_code",
  "SaleID": 249608,
  "OrderDate": "2024-12-06",
  "Customer": "Mark Snyder**",
  "FirstName": "Mark",
  "LastName": "Snyder",
  "OrderTotal": 9.99,
  "ItemSubtotal": 9.99,
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
  end

  context "#process_report" do
    let(:sale_line) {
      {
        EventCode: "random_event_code",
        SaleID: 249608,
        OrderDate: "2024-12-06",
        Customer: "Mark Snyder**",
        FirstName: "Mark",
        LastName: "Snyder",
        OrderTotal: 9.99,
        ItemSubtotal: 9.99,
        SalesTax: 0.5,
        SpecialOrderFlag: "N",
        TaxableOrderFlag: "Y",
        ProductCode: "MSC21692",
        Quantity: "1",
        UnitPrice: "9.99",
        ItemSalesTax: "0.5",
        AddressLine1: "3249 Ian Patrick",
        AddressLine2: "",
        City: "Kannapolis",
        State: "NC",
        ZipPostal: "28083",
        Country: "US",
        ShipAddressLine1: "119 Vista Lane",
        ShipAddressLine2: "",
        ShipCity: "Fairfield Bay",
        ShipState: "Arkansas",
        ShipZipPostal: "72088",
        ShipCountry: "US",
        EmailAddress: "mjsnyder7@icloud.com",
        POSImportID: 249608
      }
    }
    let(:refund_line) {
      {
        EventCode: "random_event_code",
        SaleID: 249608,
        OrderDate: "2024-12-06",
        Customer: "Mark Snyder**",
        FirstName: "Mark",
        LastName: "Snyder",
        OrderTotal: -9.99,
        ItemSubtotal: -9.99,
        SalesTax: -0.5,
        SpecialOrderFlag: "N",
        TaxableOrderFlag: "Y",
        ProductCode: "MSC21692",
        Quantity: "-1",
        UnitPrice: "-9.99",
        ItemSalesTax: "-0.5",
        AddressLine1: "3249 Ian Patrick",
        AddressLine2: "",
        City: "Kannapolis",
        State: "NC",
        ZipPostal: "28083",
        Country: "US",
        ShipAddressLine1: "119 Vista Lane",
        ShipAddressLine2: "",
        ShipCity: "Fairfield Bay",
        ShipState: "Arkansas",
        ShipZipPostal: "72088",
        ShipCountry: "US",
        EmailAddress: "mjsnyder7@icloud.com",
        POSImportID: 249608
      }
    }
    let(:bundle_sale_line) {
      {
        EventCode: "random_event_code",
        SaleID: 249608,
        OrderDate: "2024-12-06",
        Customer: "Mark Snyder**",
        FirstName: "Mark",
        LastName: "Snyder",
        OrderTotal: 14.98,
        ItemSubtotal: 14.98,
        SalesTax: 0.8,
        SpecialOrderFlag: "N",
        TaxableOrderFlag: "Y",
        ProductCode: "MSC21692|BKP21307",
        Quantity: "1|1",
        UnitPrice: "9.99|4.99",
        ItemSalesTax: "0.5|0.3",
        AddressLine1: "3249 Ian Patrick",
        AddressLine2: "",
        City: "Kannapolis",
        State: "NC",
        ZipPostal: "28083",
        Country: "US",
        ShipAddressLine1: "119 Vista Lane",
        ShipAddressLine2: "",
        ShipCity: "Fairfield Bay",
        ShipState: "Arkansas",
        ShipZipPostal: "72088",
        ShipCountry: "US",
        EmailAddress: "mjsnyder7@icloud.com",
        POSImportID: 249608
      }
    }
    let(:bundle_sale_line_more_quantity) {
      {
        EventCode: "random_event_code",
        SaleID: 249608,
        OrderDate: "2024-12-06",
        Customer: "Mark Snyder**",
        FirstName: "Mark",
        LastName: "Snyder",
        OrderTotal: 24.97,
        ItemSubtotal: 24.97,
        SalesTax: 1.30,
        SpecialOrderFlag: "N",
        TaxableOrderFlag: "Y",
        ProductCode: "MSC21692|BKP21307",
        Quantity: "2|1",
        UnitPrice: "9.99|4.99",
        ItemSalesTax: "0.5|0.3",
        AddressLine1: "3249 Ian Patrick",
        AddressLine2: "",
        City: "Kannapolis",
        State: "NC",
        ZipPostal: "28083",
        Country: "US",
        ShipAddressLine1: "119 Vista Lane",
        ShipAddressLine2: "",
        ShipCity: "Fairfield Bay",
        ShipState: "Arkansas",
        ShipZipPostal: "72088",
        ShipCountry: "US",
        EmailAddress: "mjsnyder7@icloud.com",
        POSImportID: 249608
      }
    }
    let(:same_customer_different_item) {
      {
        EventCode: "random_event_code",
        SaleID: 249608,
        OrderDate: "2024-12-06",
        Customer: "Mark Snyder**",
        FirstName: "Mark",
        LastName: "Snyder",
        OrderTotal: 14.99,
        ItemSubtotal: 14.99,
        SalesTax: 1.30,
        SpecialOrderFlag: "N",
        TaxableOrderFlag: "Y",
        ProductCode: "MSC21307",
        Quantity: "1",
        UnitPrice: "14.99",
        ItemSalesTax: "1.30",
        AddressLine1: "3249 Ian Patrick",
        AddressLine2: "",
        City: "Kannapolis",
        State: "NC",
        ZipPostal: "28083",
        Country: "US",
        ShipAddressLine1: "119 Vista Lane",
        ShipAddressLine2: "",
        ShipCity: "Fairfield Bay",
        ShipState: "Arkansas",
        ShipZipPostal: "72088",
        ShipCountry: "US",
        EmailAddress: "mjsnyder7@icloud.com",
        POSImportID: 249608
      }
    }
    let(:different_customer) {
      {
        EventCode: "random_event_code",
        SaleID: 249608,
        OrderDate: "2024-12-06",
        Customer: "Jeff Snyder**",
        FirstName: "Jeff",
        LastName: "Snyder",
        OrderTotal: 14.99,
        ItemSubtotal: 14.99,
        SalesTax: 1.30,
        SpecialOrderFlag: "N",
        TaxableOrderFlag: "Y",
        ProductCode: "MSC21307",
        Quantity: "1",
        UnitPrice: "14.99",
        ItemSalesTax: "1.30",
        AddressLine1: "3249 Ian Patrick",
        AddressLine2: "",
        City: "Kannapolis",
        State: "NC",
        ZipPostal: "28083",
        Country: "US",
        ShipAddressLine1: "119 Vista Lane",
        ShipAddressLine2: "",
        ShipCity: "Fairfield Bay",
        ShipState: "Arkansas",
        ShipZipPostal: "72088",
        ShipCountry: "US",
        EmailAddress: "jjsnyder7@icloud.com",
        POSImportID: 249608
      }
    }
    let(:bundle_refund_line) {
      {
        EventCode: "random_event_code",
        SaleID: 249608,
        OrderDate: "2024-12-06",
        Customer: "Mark Snyder**",
        FirstName: "Mark",
        LastName: "Snyder",
        OrderTotal: -14.98,
        ItemSubtotal: -14.98,
        SalesTax: -0.8,
        SpecialOrderFlag: "N",
        TaxableOrderFlag: "Y",
        ProductCode: "MSC21692|BKP21307",
        Quantity: "-1|-1",
        UnitPrice: "-9.99|-4.99",
        ItemSalesTax: "-0.5|-0.3",
        AddressLine1: "3249 Ian Patrick",
        AddressLine2: "",
        City: "Kannapolis",
        State: "NC",
        ZipPostal: "28083",
        Country: "US",
        ShipAddressLine1: "119 Vista Lane",
        ShipAddressLine2: "",
        ShipCity: "Fairfield Bay",
        ShipState: "Arkansas",
        ShipZipPostal: "72088",
        ShipCountry: "US",
        EmailAddress: "mjsnyder7@icloud.com",
        POSImportID: 249608
      }
    }

    it "should remove sale and refund lines" do
      report = [sale_line, refund_line]
      processed_report = lsi.process_report(report)
      expect(processed_report.count).to eq(0)
    end

    it "should remove item from bundle sale" do
      report = [bundle_sale_line, refund_line]
      processed_report = lsi.process_report(report)
      expect(processed_report.count).to eq(1)
      expect(processed_report.first[:OrderTotal]).to eq(4.99)
      expect(processed_report.first[:ItemSubtotal]).to eq(4.99)
      expect(processed_report.first[:SalesTax]).to eq(0.3)
      expect(processed_report.first[:ProductCode]).to eq("BKP21307")
      expect(processed_report.first[:Quantity]).to eq("1")
      expect(processed_report.first[:UnitPrice]).to eq("4.99")
      expect(processed_report.first[:ItemSalesTax]).to eq("0.3")
    end

    it "should remove item from bundle sale with more quantity" do
      report = [bundle_sale_line_more_quantity, refund_line]
      processed_report = lsi.process_report(report)
      expect(processed_report.count).to eq(1)
      expect(processed_report.first[:OrderTotal]).to eq(14.98)
      expect(processed_report.first[:ItemSubtotal]).to eq(14.98)
      expect(processed_report.first[:SalesTax]).to eq(0.8)
      expect(processed_report.first[:ProductCode]).to eq("MSC21692|BKP21307")
      expect(processed_report.first[:Quantity]).to eq("1|1")
      expect(processed_report.first[:UnitPrice]).to eq("9.99|4.99")
      expect(processed_report.first[:ItemSalesTax]).to eq("0.5|0.3")
    end

    it "should remove item from bundle sale with more quantity and extra lines" do
      report = [bundle_sale_line_more_quantity, refund_line, same_customer_different_item, different_customer]
      processed_report = lsi.process_report(report)
      expect(processed_report.count).to eq(3)
      expect(processed_report.first[:OrderTotal]).to eq(14.98)
      expect(processed_report.first[:ItemSubtotal]).to eq(14.98)
      expect(processed_report.first[:SalesTax]).to eq(0.8)
      expect(processed_report.first[:ProductCode]).to eq("MSC21692|BKP21307")
      expect(processed_report.first[:Quantity]).to eq("1|1")
      expect(processed_report.first[:UnitPrice]).to eq("9.99|4.99")
      expect(processed_report.first[:ItemSalesTax]).to eq("0.5|0.3")
      expect(processed_report.second).to eq(same_customer_different_item)
      expect(processed_report.last).to eq(different_customer)
    end

    it "should remove items from bundle refund" do
      report = [bundle_sale_line, bundle_refund_line]
      processed_report = lsi.process_report(report)
      expect(processed_report.count).to eq(0)
    end

    it "should remove items from bundle refund with more quantity" do
      report = [bundle_sale_line_more_quantity, bundle_refund_line]
      processed_report = lsi.process_report(report)
      expect(processed_report.count).to eq(1)
      expect(processed_report.first[:OrderTotal]).to eq(9.99)
      expect(processed_report.first[:ItemSubtotal]).to eq(9.99)
      expect(processed_report.first[:SalesTax]).to eq(0.5)
      expect(processed_report.first[:ProductCode]).to eq("MSC21692")
      expect(processed_report.first[:Quantity]).to eq("1")
      expect(processed_report.first[:UnitPrice]).to eq("9.99")
      expect(processed_report.first[:ItemSalesTax]).to eq("0.5")
    end
  end
end
