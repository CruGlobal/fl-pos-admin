require "rails_helper"
require "json"

describe LightspeedApiHelper do
  before do
    # set global lightspeed import service
    LightspeedApiHelper.new
    LSExtract.new
    file = File.read("#{Rails.root}/spec/fixtures/sales_formatted.json")
    JSON.parse(file)
  end

  xit("should initialize with a token holder") do
    expect(lsapi.ls_client.oauth_token).not_to be_nil
  end

  xit("should get a list of shops") do
    shops = lsapi.shops
    expect(shops.count).to be > 0
  end

  xit("should get sales") do
    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    sales = lsapi.get_sales job, 16, "2024-12-06", "2024-12-07"
    expect(sales.count).to be == 18
  end
end
