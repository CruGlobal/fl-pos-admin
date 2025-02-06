class WooRefresh
  @woo = nil

  attr_reader :woo

  def initialize
    @woo = WooCommerce::API.new(
      ENV["WOO_API_URL"].to_s,
      ENV["WOO_API_KEY"].to_s,
      ENV["WOO_API_SECRET"].to_s,
      {
        version: "wc/v3",
        wp_api: true
      }
    )
  end

  def create_job
    job = Job.create
    job.type = "WOO_REFRESH"
    job.save!
    job.status_created!
    job
  end

  def get_page job, current_page, query
    log job, "Getting page #{current_page}"
    response = @woo.get("products", query)
    response.headers["x-wp-total"]
    pages = response.headers["x-wp-totalpages"]
    response.headers["link"]
    log job, "Got page #{current_page} of #{pages}: #{response.parsed_response.count} records"
    if response.code != 200
      log job, "Error getting products from WooCommerce: #{response.code} #{response.parsed_response}"
      return results
    end
    response
  end

  def latest_refresh_timestamp
    job = Job.where(type: "WOO_REFRESH").order(created_at: :desc).first
    return nil if job.nil?
    job.created_at
  end

  def get_products_from_woo(job)
    results = []
    begin
      current_page = 1
      pages = 1
      query = {}
      query["status"] = "publish"
      query["per_page"] = 100
      query["page"] = current_page
      while current_page <= pages.to_i
        response = get_page job, current_page, query
        pages = response.headers["x-wp-totalpages"]
        results += response.parsed_response
        current_page += 1
        query["page"] = current_page
      end
    rescue => e
      log job, "Error getting products from WooCommerce: #{e.message}"
      job.status_error!
      job.save!
    end
    results
  end

  def log job, message
    log = job.logs.create(content: "[WOO_REFRESH] #{message}")
    log.save!
    Rails.logger.info log.content
  end

  def poll_jobs
    # if there are any current WOO_REFRESH jobs running, don't start another one
    if Job.where(type: "WOO_REFRESH", status: :processing).count > 0
      Rails.logger.info "POLLING: A WOO_REFRESH job is currently running."
      WoocommerceRefreshJob.set(wait: 5.minutes).perform_later
      return
    end
    # Delete all WOO_REFRESH jobs that are older than 1 day
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("DELETE FROM logs WHERE jobs_id IN (SELECT id FROM jobs WHERE type = 'WOO_REFRESH' AND created_at < NOW() - INTERVAL '1 day')")
      ActiveRecord::Base.connection.execute("DELETE FROM jobs WHERE type = 'WOO_REFRESH' AND created_at < NOW() - INTERVAL '1 day'")
    end
    job = Job.where(type: "WOO_REFRESH", status: :created).first
    if job.nil?
      Rails.logger.info "POLLING: No WOO_REFRESH jobs found."
      return
    end
    Rails.logger.info "POLLING: Found job #{job.id}. Starting job."
    handle_job job
  end

  def handle_job job
    job.status_processing!
    job.save!
    products = get_products_from_woo job
    save_products_to_db job, products
    job.status_complete!
    job.save!
  end

  def save_products_to_db job, products
    log job, "Found #{products.count} products. Saving to database."
    products.each do |product|
      woo_product = WooProduct.find_or_create_by(product_id: product["id"])
      woo_product.sku = product["sku"]
      woo_product.type = product["type"]
      woo_product.status = product["status"]
      woo_product.save!
      if woo_product.type == "bundle"
        product["bundled_items"].each do |bundled_item|
          wbi = WooProductBundle.find_or_create_by(product_id: woo_product.id, bundled_product_id: bundled_item["product_id"])
          wbi.default_quantity = bundled_item["quantity_default"]
          wbi.save!
        end
      end
      log job, "Saved product #{woo_product.product_id} with sku #{woo_product.sku}. Bundle count: #{product["bundled_items"].count}"
    end
  rescue => e
    log job, "Error saving products to database: #{e.message}"
    job.status_error!
    job.save!
  end
end
