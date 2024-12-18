require 'rails_helper'


describe LightspeedImport do

  # set global lightspeed import service
  lsi = LightspeedImport.new

  xit('should initialize with a token holder') do
    expect(lsi.ls_client.oauth_token).not_to be_nil
  end

  xit('should get a list of shops') do
    shops = lsi.get_shops
    expect(shops.count).to be > 0
  end

  xit('should initialize a new job') do
    context = lsi.new_job 16, '2024-12-01', '2024-12-31'
    expect(context[:event_code]).not_to be_nil
  end

  xit('should get sales') do
    sales = lsi.get_sales 16, '2024-12-06', '2024-12-07'
    expect(sales.count).to be == 18
  end

  xit('should get products from woo cache') do
    products = lsi.get_products_from_woo 10
    expect(products.count).to be == 10

    products = lsi.get_products_from_woo
    expect(products.count).to be > 400
  end

  it('should strip sales data to only the essentials') do
    job = lsi.create_job 16, '2024-12-06', '2024-12-07'
    sales = lsi.get_sales job, 16, '2024-12-06', '2024-12-07'
    sales = lsi.strip_to_named_fields(sales, lsi.FIELDS_TO_KEEP)
    expect(sales.first.keys.count).to be == 8
  end

end
