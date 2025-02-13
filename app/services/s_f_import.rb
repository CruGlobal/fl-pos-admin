require "salesforce_bulk_api"

class SFImport
  def initialize
  end

  def lsh
    @lsh ||= LightspeedApiHelper.new
  end

  def sf_client
    @sf_client ||= Restforce.new(
      username: ENV["SF_USERNAME"],
      password: ENV["SF_PASSWORD"],
      security_token: ENV["SF_TOKEN"],
      instance_url: ENV["SF_INSTANCE_URL"],
      host: ENV["SF_HOST"],
      client_id: ENV["SF_CLIENT_ID"],
      client_secret: ENV["SF_CLIENT_SECRET"]
    )
  end

  def log job, message
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    log = job.logs.create(content: "[#{timestamp}] #{message}")
    log.save!
    Rails.logger.info log.content
  end

  def create_job(shop_id, start_date, end_date)
    shop = lsh.find_shop(shop_id)
    context = {
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: shop.Contact["custom"]
    }
    job = Job.create(
      type: "SF_IMPORT",
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: shop.Contact["custom"],
      context: context,
      status: :created
    )
    job.save!
    job
  end

  def poll_jobs
    # if there are any current WOO_REFRESH jobs running, don't start another one
    if Job.where(type: "WOO_REFRESH", status: :processing).count > 0
      Rails.logger.info "POLLING: A WOO_REFRESH job is currently running."
      SalesforceImportJob.set(wait: 5.minutes).perform_later
      return
    end
    jobs = Job.where(type: "SF_IMPORT", status: :created).all
    if jobs.count == 0
      Rails.logger.info "POLLING: No SF_IMPORT jobs found."
      return
    end
    # Mark all found jobs as paused
    jobs.each do |job|
      job.status_paused!
      job.save!
    end
    jobs.each do |job|
      Rails.logger.info "POLLING: Found job #{job.id}. Starting job."
      handle_job job
    end
  end

  def init_sf_client
    return @sf if @sf

    sf_client.authenticate!
    @sf = SalesforceBulkApi::Api.new(sf_client)
  end

  def handle_job(job)
    # Process the job
    job.status_processing!
    job.save!
    log job, "Processing job #{job.id}"

    init_sf_client

    # Get the products from the local cache
    products = get_products
    log job, "Got products"
    bundles = get_bundles
    log job, "Got bundles"

    # Get the sales from Lightspeed
    context = job.context
    context["sales"] = lsh.get_sales(job, context["shop_id"], context["start_date"], context["end_date"])
    log job, "Got sales"

    context["sales"] = context["sales"].map { |sale| lsh.strip_to_named_fields(sale, LightspeedInventorySchema.fields_to_keep) }
    log job, "Stripped sales to only essential fields."

    context["inventory"] = get_inventory(job, context["sales"], products, bundles)
    log job, "Compiled inventory."

    # Push the inventory to SalesForce
    push_inventory_to_sf job, context["inventory"]
    log job, "Saved to SalesForce."

    # Mark the job as complete
    job.status_complete!
    job.save!
  end

  def convert_inventory_to_sf_objects(job, inventory)
    ps_objects = []
    inventory.each do |inv, v|
      ps_objects << {
        Product_Code__c: inv.to_s,
        Quantity__c: v.to_i,
        Source_Code__c: job["event_code"],
        Agent__c: "Lightspeed",
        Upsert_Key__c: "#{job["event_code"]}-#{inv}"
      }
    end
    ps_objects
  end

  def push_inventory_to_sf(job, inventory)
    ps_objects = convert_inventory_to_sf_objects(job, inventory)

    # Push the inventory to SalesForce
    upserts = []
    ps_objects.each do |ps_object|
      upserts << sf_client.create!("Product_Sale__c",
        Upsert_Key__c: ps_object[:Upsert_Key__c],
        Product_Code__c: ps_object[:Product_Code__c],
        Quantity__c: ps_object[:Quantity__c],
        Source_Code__c: ps_object[:Source_Code__c],
        Agent__c: ps_object[:Agent__c])
    end
    upserts
  end

  def get_products
    WooProduct.all
  end

  def get_bundles
    WooProductBundle.all
  end

  def get_bundled_items(id, bundles)
    bundles.select { |bundle| bundle["product_id"] == id }
  end

  def get_inventory(job, sales, products, bundles)
    # Inventory is an array of objects that follow the format: { sku: 'SKU', quantity: 1 }
    # The skus hash is used for uniqueness. Only one object per sku is allowed.
    skus = {}
    sales.each do |sale|
      next unless sale["SaleLines"]["SaleLine"]
      lines = sale["SaleLines"]["SaleLine"]
      unless lines.is_a? Array
        lines = [lines]
      end
      lines.each do |item|
        item = item["Item"]
        sku = item["customSku"]
        if is_bundle?(sku, products)
          bundle = get_bundle(sku, products)
          bundle.each do |bundled_item|
            bundled_product = products.select { |product| product["product_id"] == bundled_item["bundled_product_id"] }
            next if bundled_product.count.zero?

            bundled_sku = bundled_product["sku"]
            if skus[bundled_sku]
              skus[bundled_sku] += 1
            else
              skus[bundled_sku] = 1
            end
          end
        elsif skus[sku]
          skus[sku] += 1
        else
          skus[sku] = 1
        end
      end
    end
    inventory = []
    filtered_skus = filter_skus(skus)
    filtered_skus.each do |sku, quantity|
      inventory << {sku:, quantity:}
    end
    inventory
  end

  def filter_skus(skus)
    skus.filter { |sku, _quantity| sku != "MSC17061" && sku != "COL20277" }
  end

  def is_bundle?(sku, products)
    products.each do |product|
      if product["sku"] == sku
        return product["type"] == "bundle"
      end
    end
  end

  def get_bundle(sku, bundles)
    ret = []
    bundles.each do |bundle|
      if bundle["sku"] == sku
        ret << bundle
      end
    end
    ret
  end
end
