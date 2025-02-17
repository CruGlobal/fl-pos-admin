require "rails_helper"
require "json"

describe SFImport do
  let(:sfi) { SFImport.new }
  let(:lsh) { LightspeedApiHelper.new }

  before do
    shop = double("shop", Contact: {"custom" => "WTR25CHS1"})
    allow_any_instance_of(LightspeedApiHelper).to receive(:find_shop).and_return(shop)
    LightspeedStubHelpers.stub_lightspeed_account_request
  end

  it("should filter special orders (MSC17061) and collateral (COL20277) out of inventory") do
    skus = {}
    skus["TEST0"] = 1
    skus["MSC17061"] = 1
    skus["COL20277"] = 1
    skus["TEST1"] = 1
    skus = sfi.filter_skus skus
    expect(skus.keys.count).to eq(2)
    expect(skus.key?("MSC17061")).to eq(false)
    expect(skus.key?("COL20277")).to eq(false)
    expect(skus.key?("TEST0")).to eq(true)
    expect(skus.key?("TEST1")).to eq(true)
  end

  it("should create a new job") do
    job = sfi.create_job 16, "2024-12-01", "2024-12-31"
    expect(job[:event_code]).not_to be_nil
  end

  it("should be able to login to SalesForce") do
    expect_any_instance_of(Restforce::Data::Client).to receive(:authenticate!).and_return(true)
    expect_any_instance_of(SalesforceBulkApi::Api).to receive(:initialize).and_return(true)
    sfi.init_sf_client
  end

  it("should convert inventory to SF Product_Sale__c objects") do
    ENV["SF_AGENT"] = "Lightspeed"
    job = sfi.create_job 16, "2024-12-08", "2024-12-09"
    inventory = [{sku: "BKP21475", quantity: 9}, {sku: "BKH17526", quantity: 2}, {sku: "BKH17525", quantity: 3}, {sku: "CER21841", quantity: 19}, {sku: "MSC21693", quantity: 3}, {sku: "BKP20576", quantity: 2}, {sku: "BKP18001", quantity: 3}, {sku: "BKP13003", quantity: 3}, {sku: "BKP21762", quantity: 3}, {sku: "BKP21550", quantity: 6}, {sku: "BKP21307", quantity: 4}, {sku: "BKP21308", quantity: 4}, {sku: "BKH21586", quantity: 3}, {sku: "BKP12001", quantity: 2}, {sku: "BKP21541", quantity: 4}, {sku: "BKP21761", quantity: 4}, {sku: "BKP21411", quantity: 5}, {sku: "BKP21764", quantity: 7}, {sku: "BKH20397", quantity: 9}, {sku: "BKP20649", quantity: 1}, {sku: "BKH21579", quantity: 8}, {sku: "BKP20074", quantity: 2}, {sku: "MSC21692", quantity: 4}, {sku: "MSC17061", quantity: 4}, {sku: "BKP21289", quantity: 2}, {sku: "RPK21431", quantity: 4}, {sku: "APP21575", quantity: 2}, {sku: "APP21562", quantity: 1}, {sku: "APP21564", quantity: 2}, {sku: "BKH21610", quantity: 7}, {sku: "BKP20588", quantity: 3}, {sku: "BKP21348", quantity: 3}, {sku: "BKP21158", quantity: 2}, {sku: "BKP19056", quantity: 3}, {sku: "BKP19500", quantity: 5}, {sku: "BKP21673", quantity: 3}, {sku: "APP21563", quantity: 1}, {sku: "RPK20929", quantity: 4}, {sku: "BKP21127", quantity: 1}, {sku: "RPK20869", quantity: 1}, {sku: "BKP14193", quantity: 1}, {sku: "APP21574", quantity: 2}, {sku: "APP21565", quantity: 1}, {sku: "MAN21792", quantity: 1}, {sku: "COL20277", quantity: 1}, {sku: "MSC21145", quantity: 1}, {sku: "MSC21146", quantity: 1}]
    products = sfi.convert_inventory_to_sf_objects(job, inventory)
    expected = [{Product_Code__c: "BKP21475", Quantity__c: 9, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21475"}, {Product_Code__c: "BKH17526", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH17526"}, {Product_Code__c: "BKH17525", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH17525"}, {Product_Code__c: "CER21841", Quantity__c: 19, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-CER21841"}, {Product_Code__c: "MSC21693", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC21693"}, {Product_Code__c: "BKP20576", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP20576"}, {Product_Code__c: "BKP18001", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP18001"}, {Product_Code__c: "BKP13003", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP13003"}, {Product_Code__c: "BKP21762", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21762"}, {Product_Code__c: "BKP21550", Quantity__c: 6, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21550"}, {Product_Code__c: "BKP21307", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21307"}, {Product_Code__c: "BKP21308", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21308"}, {Product_Code__c: "BKH21586", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH21586"}, {Product_Code__c: "BKP12001", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP12001"}, {Product_Code__c: "BKP21541", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21541"}, {Product_Code__c: "BKP21761", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21761"}, {Product_Code__c: "BKP21411", Quantity__c: 5, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21411"}, {Product_Code__c: "BKP21764", Quantity__c: 7, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21764"}, {Product_Code__c: "BKH20397", Quantity__c: 9, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH20397"}, {Product_Code__c: "BKP20649", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP20649"}, {Product_Code__c: "BKH21579", Quantity__c: 8, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH21579"}, {Product_Code__c: "BKP20074", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP20074"}, {Product_Code__c: "MSC21692", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC21692"}, {Product_Code__c: "MSC17061", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC17061"}, {Product_Code__c: "BKP21289", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21289"}, {Product_Code__c: "RPK21431", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-RPK21431"}, {Product_Code__c: "APP21575", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21575"}, {Product_Code__c: "APP21562", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21562"}, {Product_Code__c: "APP21564", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21564"}, {Product_Code__c: "BKH21610", Quantity__c: 7, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKH21610"}, {Product_Code__c: "BKP20588", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP20588"}, {Product_Code__c: "BKP21348", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21348"}, {Product_Code__c: "BKP21158", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21158"}, {Product_Code__c: "BKP19056", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP19056"}, {Product_Code__c: "BKP19500", Quantity__c: 5, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP19500"}, {Product_Code__c: "BKP21673", Quantity__c: 3, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21673"}, {Product_Code__c: "APP21563", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21563"}, {Product_Code__c: "RPK20929", Quantity__c: 4, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-RPK20929"}, {Product_Code__c: "BKP21127", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP21127"}, {Product_Code__c: "RPK20869", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-RPK20869"}, {Product_Code__c: "BKP14193", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-BKP14193"}, {Product_Code__c: "APP21574", Quantity__c: 2, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21574"}, {Product_Code__c: "APP21565", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-APP21565"}, {Product_Code__c: "MAN21792", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MAN21792"}, {Product_Code__c: "COL20277", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-COL20277"}, {Product_Code__c: "MSC21145", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC21145"}, {Product_Code__c: "MSC21146", Quantity__c: 1, Source_Code__c: "WTR25CHS1", Agent__c: "Lightspeed", Upsert_Key__c: "WTR25CHS1-MSC21146"}]
    expect(products).to eq(expected)
  end

  it("should save a record to salesforce") do
    job = sfi.create_job 16, "2024-12-08", "2024-12-09"
    inventory = [{sku: "BKP21475", quantity: 9}, {sku: "BKH17526", quantity: 2}, {sku: "BKH17525", quantity: 3}, {sku: "CER21841", quantity: 19}, {sku: "MSC21693", quantity: 3}, {sku: "BKP20576", quantity: 2}, {sku: "BKP18001", quantity: 3}, {sku: "BKP13003", quantity: 3}, {sku: "BKP21762", quantity: 3}, {sku: "BKP21550", quantity: 6}, {sku: "BKP21307", quantity: 4}, {sku: "BKP21308", quantity: 4}, {sku: "BKH21586", quantity: 3}, {sku: "BKP12001", quantity: 2}, {sku: "BKP21541", quantity: 4}, {sku: "BKP21761", quantity: 4}, {sku: "BKP21411", quantity: 5}, {sku: "BKP21764", quantity: 7}, {sku: "BKH20397", quantity: 9}, {sku: "BKP20649", quantity: 1}, {sku: "BKH21579", quantity: 8}, {sku: "BKP20074", quantity: 2}, {sku: "MSC21692", quantity: 4}, {sku: "MSC17061", quantity: 4}, {sku: "BKP21289", quantity: 2}, {sku: "RPK21431", quantity: 4}, {sku: "APP21575", quantity: 2}, {sku: "APP21562", quantity: 1}, {sku: "APP21564", quantity: 2}, {sku: "BKH21610", quantity: 7}, {sku: "BKP20588", quantity: 3}, {sku: "BKP21348", quantity: 3}, {sku: "BKP21158", quantity: 2}, {sku: "BKP19056", quantity: 3}, {sku: "BKP19500", quantity: 5}, {sku: "BKP21673", quantity: 3}, {sku: "APP21563", quantity: 1}, {sku: "RPK20929", quantity: 4}, {sku: "BKP21127", quantity: 1}, {sku: "RPK20869", quantity: 1}, {sku: "BKP14193", quantity: 1}, {sku: "APP21574", quantity: 2}, {sku: "APP21565", quantity: 1}, {sku: "MAN21792", quantity: 1}, {sku: "COL20277", quantity: 1}, {sku: "MSC21145", quantity: 1}, {sku: "MSC21146", quantity: 1}]
    sfi.convert_inventory_to_sf_objects job, inventory
    expect_any_instance_of(Restforce::Data::Client).to receive(:create!).exactly(47).times
    sfi.push_inventory_to_sf job, inventory
  end

  it("should get an inventory count") do
    job = sfi.create_job 16, "2024-12-08", "2024-12-09"
    # Get the sales from Lightspeed
    # Get the products from the local cache
    products = sfi.get_products
    bundles = sfi.get_bundles

    context = job.context
    context["sales"] = JSON.parse(File.read("#{Rails.root}/spec/fixtures/2025.02.05.grand_rapids.json"))
    context["sales"] = context["sales"].map { |sale| lsh.strip_to_named_fields(sale, LightspeedInventorySchema.fields_to_keep) }
    context["inventory"] = sfi.get_inventory(job, context["sales"], products, bundles)

    expect(context["inventory"].count).to eq(0)
  end
end
