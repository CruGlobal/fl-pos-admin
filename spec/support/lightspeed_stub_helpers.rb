module LightspeedStubHelpers
  def self.stub_lightspeed_account_request
    WebMock::API.stub_request(:get, "https://api.merchantos.com/API/Account.json?limit=100&load_relations=all&offset=0").to_return(status: 200, body: "", headers: {})
  end
end
