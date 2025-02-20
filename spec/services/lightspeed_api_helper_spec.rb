require "rails_helper"
require "json"

describe LightspeedApiHelper do
  let(:lsapi) { LightspeedApiHelper.new }
  let(:lsi) { LSExtract.new }

  before do
    LightspeedStubHelpers.stub_lightspeed_account_request
    Rails.cache.write("lightspeed_auth", {token_type: "Bearer", expires_in: 3600, access_token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6IlJUX09BVVRIMl8yMDI0XzA3XzIyIn0.eyJqdGkiOiI4OTEzMDkxNzE3ZjdiZTEzNGE3ZDU2YTE0MzczMDA3NDlhZDQyMWU3ZDQ4ZGM3NjE3Mzg0OTk5Nzg1YjI2N2JmMzRkNTI5ZmJjYmVjNWIyZCIsImlzcyI6Imh0dHBzOi8vY2xvdWQubGlnaHRzcGVlZGFwcC5jb20iLCJhdWQiOiI4Zjg1OTM0MTJlOWM1ZWFjNjEwZjRhZjQ0NTk0NTdjNGM0MjkxYWZhOTlmZDRhNjNkZDQxNTNiODk0ODQxMjk5Iiwic3ViIjoiMTYxNTMxNiIsImFjY3QiOiIyNzAxMCIsInNjb3BlIjoiZW1wbG95ZWU6YWxsIiwiaWF0IjoxNzM3MDU2NDk1LjQ0MTAyMiwibmJmIjoxNzM3MDU2NDk1LjQ0MTAyMiwiZXhwIjoxNzM3MDYwMDk1LjQxODY0Nn0.ktoLAcZKvggrhiPOqRhMrBBCdI5m0MSjqZBxmJfIwxwgaWf8I_BqeDjfD4IkFHxkiOZqblelY1OjUqEpfShLuezDSWvZGXFLyEL74nZDjZ3LzR8mnXUwm1mORicR_B676ra6TTFksCfOz4Uf74aAs01AIWI54qoRz7HP59gaJLEprKdkLd5IzHoK9SmWPrXDWdm9IUCTNywNijsjkKmQolHJFXc_MlFbGi9cXnClzsKsSwkpRwmGZEt6b-TUlKjy91gdOjLASqkwzUF7_ntylBqY3Z-CszAN2LdgY4yL7_QACq-mpBvwHJJuYDxvtHkK0aGLGEQ6ah_ASUURHwKT4A", refresh_token: "def50200250b783f1086d8057eaf03b5d4289623c477709e9cdd99d2de8e27ef96e0ce606f02419289c39e31fed31cb7acb25f3e1edb6199ac16df25ea0c24d6ad31ddfeea5b91e3058b25d924aad5b2b9ac03d723324489ac7ed91ff79d354ed5a2ce258a05bf0747c3a18a9768497e5e603fcb258b34813b14b4e1b50cac0c0d0d7ca80b1581da9cf29bc1e2023f40d680acd5199244a8b90fb89b23fa3d7a03326b78bace5a389760a054a374f37699fca4945a1b4fe43686dbb3aa5e09327e39d720b89eb39f3a39f265e43c734ea292d3be5437fccc3faf735a8395e15336cc27ad3e54531e8a83326e2f04a62b73b157c71c4a942f1d8108a625c11f90020531129fe39f78882ac094acba2eb2f8cb33af476731a1c53c601fca6ece4f31ff0ca29c152df583df67d1a63159302fe635a2b25e92d0a105c6a1f6b3ede938d2d9c02a7d2a2d4bf6b81d4b54a1c00a9064bba645536f7bf48b50efecd46df34a34018da4c1bf14eb4c32c22ec2d0ff01fd6bd9d42e9eb13f92d644b0819451550431a380563122c8b6c7c0f30f56243a486659de9809b8a7328d77ee2e4f0448ffd9cb66c12be4f5be460118ae27c18844810f32"}.to_json)

    accounts = double("accounts", all: [Lightspeed::Account.new])
    allow_any_instance_of(Lightspeed::Client).to receive(:accounts).and_return(accounts)
    shops = double("shops", all: [Lightspeed::Shop.new], find: Lightspeed::Shop.new)
    allow_any_instance_of(Lightspeed::Account).to receive(:shops).and_return(shops)

    event_address = {
      "Conference_Location__r" => {
        "ShippingStreet" => "Weekend to Remember Planner: Jon Tippman\n187 Monroe Ave NW",
        "ShippingCity" => "Grand Rapids",
        "ShippingState" => "MI",
        "ShippingPostalCode" => "49503-2666"
      }
    }
    allow_any_instance_of(Restforce::Data::Client).to receive(:query).and_return([event_address])
  end

  it("should initialize with a token holder") do
    expect(lsapi.ls_client.oauth_token).not_to be_nil
  end

  it("should get a list of shops") do
    shops = lsapi.shops
    expect(shops.count).to be > 0
  end

  it("should get sales") do
    allow_any_instance_of(LightspeedApiHelper).to receive(:find_shop).and_return(double("shop", id: 1, Contact: {firstName: "John", lastName: "Doe"}, name: "Test Shop"))
    allow_any_instance_of(Lightspeed::Sales).to receive(:size).and_return(18)
    allow_any_instance_of(Lightspeed::Sales).to receive(:all).and_return([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18])

    job = lsi.create_job 16, "2024-12-06", "2024-12-07"
    sales = lsapi.get_sales job, 16, "2024-12-06", "2024-12-07"
    expect(sales.count).to be == 18
  end

  it("can get a shipping address") do
    sales = JSON.parse(File.read("#{Rails.root}/spec/fixtures/2025.02.05.grand_rapids.json"))
    test = sales.find { |sale| sale["saleID"] == 250210 }
    expect(lsapi.get_shipping_address(test, "address1")).to eq("550 Riley St.")
    expect(lsapi.get_shipping_address(test, "city")).to eq("Lansing")
    expect(lsapi.get_shipping_address(test, "state")).to eq("MI")
    expect(lsapi.get_shipping_address(test, "zip")).to eq("48910")
  end
end
