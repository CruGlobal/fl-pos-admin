require "rails_helper"

describe WooRefresh do
  self.use_transactional_tests = false

  let(:woo) { WooRefresh.new }

  before do
    allow_any_instance_of(WooCommerce::API).to receive(:get).and_return(HTTParty::Response.new(double("request", options: {}), double("response", body: "", code: 200, to_hash: {"x-wp-totalpages" => 1}), double("parsed_block", call: [1, 2, 3])))
  end

  it("it should initialize with a woo client") do
    expect(woo.woo).not_to be_nil
  end

  it("it should log a message") do
    job = Job.create(type: "WOO_REFRESH")
    woo.log job, "Test message"
    expect(AppLog.where(jobs_id: job.id, content: "[WOO_REFRESH] Test message").count).to be > 0
  end

  it("it should get a page of products") do
    job = Job.create(type: "WOO_REFRESH")
    response = woo.get_page job, 1, {status: "publish", per_page: 1, page: 1}
    expect(response.code).to eq(200)
    expect(response.parsed_response.count).to eq(3)
  end

  it("it should get products from woo") do
    job = woo.create_job
    products = woo.get_products_from_woo(job)
    expect(products.count).to eq(3)
  end

  it("it should create a job") do
    job = woo.create_job
    expect(job.type).to eq("WOO_REFRESH")
  end

  it("it should save products to the db") do
    allow(woo).to receive(:get_page).and_return([{"id" => 1, "name" => "Test Product", "price" => "10.00", "sku" => "12345", "description" => "Test Description", "bundled_items" => [], "categories" => [{"id" => 1, "name" => "Test Category"}]}])

    job = woo.create_job
    products = woo.get_page job, 1, {status: "publish", per_page: 1, page: 1}
    woo.save_products_to_db job, products
    expect(WooProduct.count).to be > 0
  end

  it "should delete products that are no longer in woo" do
    allow(woo).to receive(:get_page).and_return([{"id" => 1, "name" => "Test Product", "price" => "10.00", "sku" => "12345", "description" => "Test Description", "bundled_items" => [], "categories" => [{"id" => 1, "name" => "Test Category"}]}])
    create(:woo_product, product_id: 30)

    job = woo.create_job
    products = woo.get_page job, 1, {status: "publish", per_page: 1, page: 1}
    woo.save_products_to_db job, products
    expect(WooProduct.count).to eq(1)
    expect(WooProduct.find_by(product_id: 30)).to be_nil
  end

  it("it should handle a job") do
    job = woo.create_job
    woo.handle_job job
    job.reload
    expect(job.status).to eq("complete")
  end
end
