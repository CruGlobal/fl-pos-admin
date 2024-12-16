require 'woocommerce_api'

class LightspeedImport

  @ls_client = nil
  @ls_account = nil
  @woo = nil

  def initialize
    @ls_client = Lightspeed::Client.new(oauth_token_holder: LightspeedTokenHolder.new)
    @ls_account = @ls_client.accounts.all.first
    @woo = WooCommerce::API.new(
      ENV['WOO_API_URL'].to_s,
      ENV['WOO_API_KEY'].to_s,
      ENV['WOO_API_SECRET'].to_s,
      {
        version: "v3"
      }
    )
  end

  def ls_client
    @ls_client
  end

  def ls_account
    @ls_account
  end

  def woo
    @woo
  end

  def get_shops
    shops = @ls_account.shops.all
    shops
  end

  def get_products_from_woo(limit = 0)
    query = {
      status:'publish',
    }
    if limit > 0
      query[:limit] = limit
    end
    response = @woo.get("products", query)
    if response.code != 200
      puts "Error getting products from WooCommerce"
      puts response
      return []
    end
    response.parsed_response
  end

  def new_job(shop_id, start_date, end_date)
    shop = @ls_account.shops.find(shop_id)
    context = {
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: shop.Contact['custom']
    }
    # TODO: eventually save this in the job table
    context
  end

  def get_sales(shop_id, start_date, end_date)
    # /Account/27010/Sale.json?
    # sort=completeTime
    # &completed=true
    # &load_relations=all
    # &shopID=16
    # &completed=true
    # &completeTime=><,2020-01-01,2020-01-31
    params = {
      shopID: shop_id,
      load_relations: 'all',
      completed: 'true',
      completeTime: "><,#{start_date},#{end_date}",
    }
    count = @ls_account.sales.size(params: params)
    sales = @ls_account.sales.all(params: params)
    sales
  end

  def process_job(job_id)
    # TODO
    # Process the job
    # 1. Get job record from the jobs table
    # 2. Update the job status to PROCESSING
    # Get the job context
    # Get list of all sales for the shop_id between start_date and end_date (paging included)
    # Optimize sales data to remove extreneous data from the Object
    # Save the sales data to the context object
    # Log messageg "Sales retrived from Lightspeed
  end

  def complete_job(job_id)
    # TODO
    # Get job record from the jobs table
    # Update the job status to COMPLETED
  end

  def start_jobs
    # TODO
    # Poll the jobs table for any job in CREATED status
    # If found, start the job
  end
end
