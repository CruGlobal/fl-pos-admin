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
    codes = lsh.get_all_unit_prices(example_sales[2], example_sales[2]["calcSubtotal"].to_f)
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

  it("should get a shipping customers") do
    ls_account = double("ls_account")
    customers = double("customers")
    allow(ls_account).to receive(:customers).and_return(customers)
    allow(customers).to receive(:size).and_return(2)
    allow(customers).to receive(:all).and_return([1, 2])
    lsh.ls_account = ls_account

    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    customers = lsh.get_shipping_customers(job, example_sales)
    expect(customers.count).to be == 2
  end

  it("should be able to get a shipping address field") do
    customers_mock = [double("customers", customerID: 1064752, Contact: {"Addresses" => [{"ContactAddress" => {"address1" => "119 Vista Lane"}}]})]
    allow(lsh).to receive(:get_shipping_customers).and_return(customers_mock)

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
    customers_mock = [double("customers", customerID: 1064752, Contact: {"Addresses" => [{"ContactAddress" => {"address1" => "119 Vista Lane", "city" => "Fairfield Bay", "state" => "Arkansas", "zip" => "72088"}}]})]
    allow(lsh).to receive(:get_shipping_customers).and_return(customers_mock)

    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    sale = example_sales[1]
    sale = lsh.strip_to_named_fields(sale, LightspeedSaleSchema.fields_to_keep)
    customers = lsh.get_shipping_customers(job, example_sales)
    products = lsi.get_products
    line = lsi.get_report_line(job, sale, products, customers)
    expected = '{
  "EventCode": "random_event_code",
  "SaleID": 249608,
  "OrderDate": "2024-12-06",
  "Customer": "Mark Snyder**",
  "FirstName": "Mark",
  "LastName": "Snyder**",
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
    puts line.inspect
  end
end
