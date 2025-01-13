require 'rails_helper'

describe WooRefresh do
  self.use_transactional_tests = false

  # set global lightspeed import service
  woo = WooRefresh.new

  xit('it should initialize with a woo client') do
    expect(woo.woo).not_to be_nil
  end

  xit('it should log a message') do
    job = Job.create
    job.type = 'WOO_REFRESH'
    job.save!
    woo.log job, 'Test message'
    expect(AppLog.where(jobs_id: job.id, content: '[WOO_REFRESH] Test message').count).to be > 0
  end

  xit('it should get a page of products') do
    job = Job.create
    job.type = 'WOO_REFRESH'
    job.save!
    response = woo.get_page job.id, 1, 1, { status: 'publish', per_page: 1, page: 1 }
    expect(response.code).to be == 200
    expect(response.parsed_response.count).to be == 1
  end

  xit('it should get products from woo') do
    job = woo.create_job
    products = woo.get_products_from_woo(job)
    expect(products.count).to be >= 700
  end

  xit('it should create a job') do
    job = woo.create_job
    expect(job.type).to eq('WOO_REFRESH')
  end

  xit('it should poll jobs') do

  end

  xit('it should save products to the db') do
    job = woo.create_job
    products = woo.get_page job, 1, 1, { status: 'publish', per_page: 1, page: 1 }
    puts "PRODUCTS: #{products}"
    woo.save_products_to_db job, products
    expect(WooProduct.count).to be > 0
  end

  xit('it should handle a job') do
    job = woo.create_job
    woo.handle_job job
    job.reload
    expect(job.status).to eq('complete')
  end
end
