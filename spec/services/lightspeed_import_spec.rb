require 'rails_helper'

describe LightspeedImport do
  # set global lightspeed import service
  lsi = LightspeedImport.new

  it('should initialize with a token holder') do
    expect(lsi.ls_client.oauth_token).not_to be_nil
  end

  it('should get a list of shops') do
    shops = lsi.get_shops
    expect(shops.count).to be > 0
  end

  it('should initialize a new job') do
    context = lsi.new_job 16, '2024-12-01', '2024-12-31'
    expect(context[:event_code]).not_to be_nil
  end

  it('should get sales') do
    sales = lsi.get_sales 16, '2024-12-06', '2024-12-07'
    expect(sales.count).to be == 18
  end

  fit('should get woo products') do
    products = lsi.get_products_from_woo 1
    expect(products.count).to be > 0
  end
end
