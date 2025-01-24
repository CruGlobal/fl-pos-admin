class LightspeedApiHelper
  @ls_client = nil
  @ls_account = nil

  attr_accessor :ls_client, :ls_account

  def initialize
    @ls_client = Lightspeed::Client.new(oauth_token_holder: LightspeedTokenHolder.new)
    @ls_account = @ls_client.accounts.all.first
  end

  def strip_to_named_fields(record, fields_to_keep)
    if record.is_a?(Array)
      return record.map { |r| recurse_strip(r, fields_to_keep) }
    end
    recurse_strip(record, fields_to_keep)
  end

  def recurse_strip(record, fields_to_keep)
    strip(record, fields_to_keep)
  end

  def strip(record, fields_to_keep)
    rec = record.as_json
    return unless fields_to_keep["root"]

    output = {}

    fields_to_keep["root"].each do |field|
      Rails.logger.info "Field: #{field}"
      unless fields_to_keep[field] # Scalar value if no child fields are defined
        value = rec[field.to_sym] || rec[field]
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

      unless fields_to_keep[field]["arrayable"]
        output[field] = recurse_strip(child, fields_to_keep[field])
        next
      end
      child = child.is_a?(Array) ? child : [child]
      output[field] = child.map { |c| recurse_strip(c, fields_to_keep[field]) }
    end

    output
  end

  def shops
    @ls_account.shops.all
  end

  def log job, message
    log = job.logs.create(content: "[LS_HELPER] #{message}")
    log.save!
    Rails.logger.info log.content
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
      load_relations: "all",
      completed: "true",
      voided: "false",
      completeTime: "><,#{start_date},#{end_date}"
    }
    count = @ls_account.sales.size(params: params)
    log job, "Found #{count} sales."
    @ls_account.sales.all(params: params)
  end

  def get_shipping_customers(job, sales)
    ids = []
    sales.each do |sale|
      ship_to_id = sale["shipToID"].to_i
      next unless ship_to_id > 0

      ids << sale["shipToID"]
    end
    return [] unless ids.count > 0

    params = {
      customerID: "IN,[#{ids.uniq.join(",")}]",
      load_relations: "all"
    }
    count = @ls_account.customers.size(params: params)
    log job, "Found #{count} shipping customers."
    @ls_account.customers.all(params: params)
  end

  def find_shop(shop_id)
    @ls_account.shops.find(shop_id)
  end

  def get_address_object(customer)
    contact = customer["Contact"]
    return unless contact

    addresses = contact["Addresses"]
    return unless addresses

    unless addresses.is_a?(Array)
      addresses = [addresses]
    end

    address = addresses.first

    ca = address["ContactAddress"]
    return unless ca

    ca
  end

  def get_address(sale, field)
    customer = sale["Customer"]
    return unless customer

    address = get_address_object(customer)
    return unless address[field]

    address[field]
  end

  def get_shipping_address(sale, customers, field)
    return unless sale["shipToID"].to_i != 0

    filtered = customers.select { |c| c.customerID == sale["shipToID"].to_i }
    customer = filtered.first
    return unless customer

    addresses = customer.Contact["Addresses"]
    return unless addresses

    unless addresses.is_a?(Array)
      addresses = [addresses]
    end

    return unless addresses.count > 0

    address = addresses.first

    ca = address["ContactAddress"]
    return unless ca

    return unless ca[field]

    ca[field]
  end

  def get_email_addresses(sale)
    customer = sale["Customer"]
    return unless customer

    contact = customer["Contact"]
    return unless contact

    emails = contact["Emails"]
    return unless emails

    unless emails.is_a?(Array)
      emails = [emails]
    end

    addys = []
    emails.each do |email|
      ce = email["ContactEmail"]
      next unless ce

      addys << ce["address"]
    end
    addys
  end

  def get_all_product_codes(sale)
    codes = []
    sale["SaleLines"].each do |line|
      line.each do |salelines|
        next unless salelines.is_a?(Array)

        salelines.each do |sl|
          codes << sl["Item"]["customSku"]
        end
      end
    end
    codes
  end

  def get_all_quantities(sale)
    quantities = []
    sale["SaleLines"].each do |line|
      line.each do |salelines|
        if salelines.is_a?(Array)
          salelines.each do |sl|
            quantities << sl["unitQuantity"]
          end
        end
      end
    end
    quantities
  end

  def get_all_unit_prices(sale)
    prices = []
    sale["SaleLines"].each do |line|
      line.each do |salelines|
        if salelines.is_a?(Array)
          salelines.each do |sl|
            prices << sl["calcTotal"]
          end
        end
      end
    end
    prices
  end

  def get_all_unit_taxes(sale)
    taxes = []
    sale["SaleLines"].each do |line|
      line.each do |salelines|
        if salelines.is_a?(Array)
          salelines.each do |sl|
            taxes << sl["calcTax1"].to_f + sl["calcTax2"].to_f
          end
        end
      end
    end
    taxes
  end

  def get_taxable_order_flag(sale)
    sale["SaleLines"].each do |line|
      line.each do |salelines|
        if salelines.is_a?(Array)
          salelines.each do |sl|
            if sl["tax"] == true
              return "Y"
            end
          end
        end
      end
    end

    "N"
  end

  # If a any SaleLines.SaleLine.isSpecialOrder is true, then the SpecialOrderFlag should be set to 'Y'
  def get_special_order_flag(sale)
    sale["SaleLines"].each do |line|
      line.each do |salelines|
        if salelines.is_a?(Array)
          salelines.each do |sl|
            if sl["isSpecialOrder"] == true
              return "Y"
            end
          end
        end
      end
    end

    "N"
  end
end
