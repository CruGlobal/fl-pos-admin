require 'woocommerce_api'

class LightspeedImport

  @ls_client = nil
  @ls_account = nil
  FIELDS_TO_KEEP = {
    'arrayable' => false,
    'root' => [
      'saleID',
      'completed',
      'voided',
      'calcTotal',
      'calcSubtotal',
      'Customer',
      'SaleLines',
      'taxTotal'
    ],
    'SaleLines' => {
      'arrayable' => false,
      'root' => ['SaleLine'],
      'SaleLine' => {
        'arrayable' => true,
        'root' => ['unitQuantity', 'isSpecialOrder', 'calcTotal', 'Item'],
        'Item' => {
          'arrayable' => false,
          'root' => ['customSku']
        }
      }
    },
    'SalePayments' => {
      'arrayable' => false,
      'root' => ['SalePayment'],
      'SalePayment' => {
        'arrayable' => true,
        'root' => ['amount']
      }
    },
    'Customer' => {
      'arrayable' => false,
      'root' => ['firstName', 'lastName', 'Contact'],
      'Contact' => {
        'arrayable' => false,
        'root' => ['Addresses'],
        'Addresses' => {
          'arrayable' => true,
          'root' => ['ContactAddress'],
          'ContactAddress' => {
            'arrayable' => false,
            'root' => ['address1', 'city', 'state', 'zip']
          }
        },
        'Phones' => {
          'arrayable' => true,
          'root' => ['number', 'useType']
        },
        'Emails' => {
          'arrayable' => true,
          'root' => ['ContactEmail'],
          'ContactEmail' => {
            'arrayable' => false,
            'root' => ['address', 'useType']
          }
        }
      }
    }
  }.freeze

  def FIELDS_TO_KEEP
    FIELDS_TO_KEEP
  end

  def initialize
    @ls_client = Lightspeed::Client.new(oauth_token_holder: LightspeedTokenHolder.new)
    @ls_account = @ls_client.accounts.all.first
  end

  def ls_client
    @ls_client
  end

  def ls_account
    @ls_account
  end

  def get_shops
    shops = @ls_account.shops.all
    shops
  end

  def strip_to_named_fields(record, fields_to_keep)
    if(record.is_a?(Array))
      return record.map { |r| recurse_strip(r, fields_to_keep) }
    end
    recurse_strip(record, fields_to_keep)
  end

  def recurse_strip(record, fields_to_keep)
    strip(record, fields_to_keep)
  end

  def strip(record, fields_to_keep)
    rec = record.as_json
    return unless fields_to_keep['root']

    output = {}

    fields_to_keep['root'].each do |field|
      unless fields_to_keep[field]# Scalar value if no child fields are defined
        value = rec[field.to_sym] || rec[field]
        if field == 'displayableSubtotal'
        end
        output[field] = value
        next
      end

      child = rec[field.to_sym] || rec[field]
      unless child
        next
      end
      unless fields_to_keep[field]
        next
      end

      unless fields_to_keep[field]['arrayable']
        output[field] = recurse_strip(child, fields_to_keep[field])
        next
      end
      child = child.is_a?(Array) ? child : [child]
      output[field] = child.map { |c| recurse_strip(c, fields_to_keep[field]) }
    end

    output
  end

  def get_products_from_woo(limit = 0)
    if(limit == 0)
      return WooProduct.all
    end
    WooProduct.all.limit(limit)
  end

  def create_job(shop_id, start_date, end_date)
    shop = @ls_account.shops.find(shop_id)
    context = {
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: shop.Contact['custom']
    }
    job = Job.create(
      type: 'LS_EXTRACT',
      shop_id: shop_id,
      start_date: start_date,
      end_date: end_date,
      event_code: shop.Contact['custom'],
      context: context
    )
    job.save!
    job
  end

  def log job, message
    log = job.logs.create(content: "[LS_EXTRACT] #{message}")
    log.save!
    puts log.content
  end

  def get_sales(job, shop_id, start_date, end_date)
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
      voided: 'false',
      completeTime: "><,#{start_date},#{end_date}",
    }
    count = @ls_account.sales.size(params: params)
    log job, "Found #{count} sales."
    sales = @ls_account.sales.all(params: params)
    sales
  end

  def poll_jobs
    # if there are any current WOO_REFRESH jobs running, don't start another one
    if Job.where('type': 'WOO_REFRESH', status: :status_processing).count > 0
      puts "POLLING: A WOO_REFRESH job is currently running."
      return
    end
    if Job.where('type': 'LS_EXTRACT', status: :status_processing).count > 0
      puts "POLLING: A LS_EXTRACT job is currently running."
      return
    end
    jobs = Job.where('type': 'LS_EXTRACT', status: :status_created).all
    if jobs.count == 0
      puts "POLLING: No LS_EXTRACT jobs found."
      return
    end
    # Mark all found jobs as paused
    jobs.each do |job|
      job.status_paused!
      job.save!
    end
    jobs.each do |job|
      puts "POLLING: Found job #{job.id}. Starting job."
      handle_job job
    end
  end

  def process_job(job)
    # TODO
    # Process the job
    job.status_processing!
    job.save!
    log job, "Processing job #{job.id}"
    # Get the job context, which is a jsonb store in the context column
    context = job.context
    # Get list of all sales for the shop_id between start_date and end_date (paging included)
    context.sales = get_sales(job, context['shop_id'], context['start_date'], context['end_date'])
    # Optimize sales data to remove extreneous data from the Object
    context.sales = context.sales.map { |sale| strip_to_named_fields(sale, FIELDS_TO_KEEP) }
    # delete the sales variable to free up memory
    # Save the sales data to the context object
    job.context = context
    job.save!
    log job, "Sales retrieved from Lightspeed"
    # Generate the report
    context.report = generate_report(context.sales)
  end

  def generate_report(sales)
    products = get_products_from_woo
    report = []
    sales.each do |sale|
      # TODO: 
    end
  end

  def complete_job(job)
    # TODO
    # Get job record from the jobs table
    # Update the job status to COMPLETED
  end

end
