class LightspeedImport
  def initialize
    @client = Lightspeed::Client.new
  end

  def extract
    @client.get('/products.json')
  end
end
