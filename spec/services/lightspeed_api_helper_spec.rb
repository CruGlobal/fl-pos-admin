require 'rails_helper'
require 'json'

describe LightspeedApiHelper do
  # set global lightspeed import service
  lsapi = LightspeedApiHelper.new
  lsi = LSExtract.new
  file = File.read("#{Rails.root}/spec/services/fixtures/sales_formatted.json")
  example_sales = JSON.parse(file)


  it('should initialize with a token holder') do
    expect(lsapi.ls_client.oauth_token).not_to be_nil
  end

  it('should get a list of shops') do
    shops = lsapi.shops
    expect(shops.count).to be > 0
  end

  it('should get sales') do
    job = lsi.create_job 16, '2024-12-06', '2024-12-07'
    sales = lsapi.get_sales job, 16, '2024-12-06', '2024-12-07'
    expect(sales.count).to be == 18
  end

end
