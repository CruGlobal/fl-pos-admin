require "rails_helper"
require "json"

describe SFImport do
  let(:sfi) { SFImport.new }
  let(:lsh) { LightspeedApiHelper.new }

  before do
    shop = double("shop")
    allow_any_instance_of(LightspeedApiHelper).to receive(:find_shop).and_return(shop)
    allow(shop).to receive("Contact").and_return({"custom" => "random_event_code"})

    create_list(:woo_product, 401)

    allow_any_instance_of(WooRefresh).to receive(:latest_refresh_timestamp).and_return(1.hour.ago)
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(nil)
    LightspeedStubHelpers.stub_lightspeed_account_request
  end

  it("should filter special orders (MSC17061) and collateral (COL20277) out of inventory") do
    skus = {}
    skus["TEST0"] = 1
    skus["MSC17061"] = 1
    skus["COL20277"] = 1
    skus["TEST1"] = 1
    skus = sfi.filter_skus skus
    expect skus.keys.count == 2
    expect skus.key?("MSC17061") == false
    expect skus.key?("COL20277") == false
    expect skus.key?("TEST0") == true
    expect skus.key?("TEST1") == true
  end

  xit("should create a new job") do
    job = sfi.create_job 16, "2024-12-01", "2024-12-31"
    expect(job[:event_code]).not_to be_nil
  end

  xit("should be able to login to SalesForce") do
    sfi.init_sf_client
    puts "Logged in to SalesForce"
  end

  xit("should convert inventory to SF Product_Sale__c objects") do
    job = sfi.create_job 16, "2024-12-08", "2024-12-09"
    inventory = {BKP21475: 9, BKH17526: 2, BKH17525: 3, CER21841: 19, MSC21693: 3, BKP20576: 2, BKP18001: 3, BKP13003: 3, BKP21762: 3, BKP21550: 6, BKP21307: 4, BKP21308: 4, BKH21586: 3, BKP12001: 2, BKP21541: 4, BKP21761: 4, BKP21411: 5, BKP21764: 7, BKH20397: 9, BKP20649: 1, BKH21579: 8, BKP20074: 2, MSC21692: 4, MSC17061: 4, BKP21289: 2, RPK21431: 4, APP21575: 2, APP21562: 1, APP21564: 2, BKH21610: 7, BKP20588: 3, BKP21348: 3, BKP21158: 2, BKP19056: 3, BKP19500: 5, BKP21673: 3, APP21563: 1, RPK20929: 4, BKP21127: 1, RPK20869: 1, BKP14193: 1, APP21574: 2, APP21565: 1, MAN21792: 1, COL20277: 1, MSC21145: 1, MSC21146: 1}
    products = sfi.convert_inventory_to_sf_objects(job, inventory)
    expected = [{Product_Code__c: "BKP21475", Quantity__c: 9, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21475"}, {Product_Code__c: "BKH17526", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH17526"}, {Product_Code__c: "BKH17525", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH17525"}, {Product_Code__c: "CER21841", Quantity__c: 19, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-CER21841"}, {Product_Code__c: "MSC21693", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC21693"}, {Product_Code__c: "BKP20576", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP20576"}, {Product_Code__c: "BKP18001", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP18001"}, {Product_Code__c: "BKP13003", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP13003"}, {Product_Code__c: "BKP21762", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21762"}, {Product_Code__c: "BKP21550", Quantity__c: 6, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21550"}, {Product_Code__c: "BKP21307", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21307"}, {Product_Code__c: "BKP21308", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21308"}, {Product_Code__c: "BKH21586", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH21586"}, {Product_Code__c: "BKP12001", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP12001"}, {Product_Code__c: "BKP21541", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21541"}, {Product_Code__c: "BKP21761", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21761"}, {Product_Code__c: "BKP21411", Quantity__c: 5, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21411"}, {Product_Code__c: "BKP21764", Quantity__c: 7, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21764"}, {Product_Code__c: "BKH20397", Quantity__c: 9, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH20397"}, {Product_Code__c: "BKP20649", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP20649"}, {Product_Code__c: "BKH21579", Quantity__c: 8, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH21579"}, {Product_Code__c: "BKP20074", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP20074"}, {Product_Code__c: "MSC21692", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC21692"}, {Product_Code__c: "MSC17061", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC17061"}, {Product_Code__c: "BKP21289", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21289"}, {Product_Code__c: "RPK21431", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-RPK21431"}, {Product_Code__c: "APP21575", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21575"}, {Product_Code__c: "APP21562", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21562"}, {Product_Code__c: "APP21564", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21564"}, {Product_Code__c: "BKH21610", Quantity__c: 7, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH21610"}, {Product_Code__c: "BKP20588", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP20588"}, {Product_Code__c: "BKP21348", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21348"}, {Product_Code__c: "BKP21158", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21158"}, {Product_Code__c: "BKP19056", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP19056"}, {Product_Code__c: "BKP19500", Quantity__c: 5, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP19500"}, {Product_Code__c: "BKP21673", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21673"}, {Product_Code__c: "APP21563", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21563"}, {Product_Code__c: "RPK20929", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-RPK20929"}, {Product_Code__c: "BKP21127", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21127"}, {Product_Code__c: "RPK20869", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-RPK20869"}, {Product_Code__c: "BKP14193", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP14193"}, {Product_Code__c: "APP21574", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21574"}, {Product_Code__c: "APP21565", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21565"}, {Product_Code__c: "MAN21792", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MAN21792"}, {Product_Code__c: "COL20277", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-COL20277"}, {Product_Code__c: "MSC21145", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC21145"}, {Product_Code__c: "MSC21146", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC21146"}]
    expect(products.to_json).to eq(expected.to_json)
  end

  xit("should save a record to salesforce") do
    # This test cannot be verified programmatically. Records must be verified
    # manually in the Salesforce UI.
    job = sfi.create_job 16, "2024-12-08", "2024-12-09"
    inventory = {BKP21475: 9, BKH17526: 2, BKH17525: 3, CER21841: 19, MSC21693: 3, BKP20576: 2, BKP18001: 3, BKP13003: 3, BKP21762: 3, BKP21550: 6, BKP21307: 4, BKP21308: 4, BKH21586: 3, BKP12001: 2, BKP21541: 4, BKP21761: 4, BKP21411: 5, BKP21764: 7, BKH20397: 9, BKP20649: 1, BKH21579: 8, BKP20074: 2, MSC21692: 4, MSC17061: 4, BKP21289: 2, RPK21431: 4, APP21575: 2, APP21562: 1, APP21564: 2, BKH21610: 7, BKP20588: 3, BKP21348: 3, BKP21158: 2, BKP19056: 3, BKP19500: 5, BKP21673: 3, APP21563: 1, RPK20929: 4, BKP21127: 1, RPK20869: 1, BKP14193: 1, APP21574: 2, APP21565: 1, MAN21792: 1, COL20277: 1, MSC21145: 1, MSC21146: 1}
    sfi.convert_inventory_to_sf_objects job, inventory
    sfi.push_inventory_to_sf job, inventory
    inserted = sfi.get_inventory_from_salesforce job, "WTR25CHS1"
    puts "Upserted: #{inserted.inspect}"
  end

  xit("should get an inventory count") do
    job = sfi.create_job 16, "2024-12-08", "2024-12-09"
    # Get the sales from Lightspeed
    # Get the products from the local cache
    products = sfi.get_products
    bundles = sfi.get_bundles

    context = job.context
    context["sales"] = lsh.get_sales(job, context["shop_id"], context["start_date"], context["end_date"])
    context["sales"] = context["sales"].map { |sale| lsh.strip_to_named_fields(sale, LightspeedInventorySchema.fields_to_keep) }
    context["inventory"] = sfi.get_inventory(job, context["sales"], products, bundles)

    puts "Inventory: #{context["inventory"]}"
    puts "Inventory count: #{context["inventory"].count}"
  end
end
