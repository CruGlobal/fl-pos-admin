class LightspeedApiHelper
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

  def custom_round(value)
    # Split the value into integer and fractional parts
    integer_part, fractional_part = value.to_s.split(".")
    fractional_part = fractional_part.ljust(3, "0") # Ensure at least 3 decimal places

    # Extract the first three decimal places
    first_two_decimals = fractional_part[0..1].to_i
    third_decimal = fractional_part[2].to_i

    # Apply the custom rounding logic
    if third_decimal < 6
      # Round down (truncate after two decimal places)
      "#{integer_part}.#{first_two_decimals}".to_f
    else
      # Round up (add 0.01 to the first two decimal places)
      "#{integer_part}.#{first_two_decimals}".to_f + 0.01

    end
  end

  def strip(record, fields_to_keep)
    rec = record.as_json
    return unless fields_to_keep["root"]

    output = {}

    fields_to_keep["root"].each do |field|
      unless fields_to_keep[field] # Scalar value if no child fields are defined
        value = rec[field.to_sym] || rec[field]
        output[field] = value
        next
      end

      child = rec[field.to_sym] || rec[field]
      unless child.present?
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

  def get_sale(sale_id)
    params = {
      saleID: sale_id,
      load_relations: "all"
    }
    @ls_account.sales.all(params: params)
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

    unless ca.is_a?(Array)
      ca = [ca]
    end

    ca.first
  end

  def get_address(sale, field)
    customer = sale["Customer"]
    return unless customer

    address = get_address_object(customer)
    return unless address

    address[field]
  end

  def get_shipping_address(sale, field)
    return unless sale['ShipTo'].present?

    customer = sale['ShipTo']
    addresses = customer['Contact']['Addresses']
    return unless addresses

    unless addresses.is_a?(Array)
      addresses = [addresses]
    end

    return unless addresses.count > 0

    address = addresses.first

    ca = address["ContactAddress"]
    return unless ca

    if ca.is_a?(Array)
      ca = ca.first
    end

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
      ces = email["ContactEmail"]
      next unless ces

      unless ces.is_a?(Array)
        ces = [ces]
      end

      ces.each do |ce|
        next unless ce["address"]

        addys << ce["address"]
      end
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

  def get_discount(saleline)
    discount = 0.0
    if saleline["calcLineDiscount"]
      discount = saleline["calcLineDiscount"].to_f.round(2)
    elsif saleline["discountAmount"]
      discount = saleline["discountAmount"].to_f.round(2)
    elsif saleline["discountPercent"]
      discount = (saleline["calcSubtotal"].to_f * saleline["discountPercent"].to_f).round(2)
    end
    discount
  end

  def get_all_unit_prices(sale)
    prices = []
    sale["SaleLines"].each do |line|
      line.each do |salelines|
        if salelines.is_a?(Array)
          salelines.each do |sl|
            # discount = get_discount(sl)
            price = sl["displayableSubtotal"].to_f.round(2)
            prices << price
          end
        end
      end
    end
    prices.map { |p| format("%.2f", p).to_f.round(2) }
  end

  def get_all_unit_taxes(sale, tax_total)
    taxes = []
    total = 0
    sale["SaleLines"].each do |line|
      line.each do |salelines|
        if salelines.is_a?(Array)
          salelines.each do |sl|
            tax = custom_round(sl["calcTax1"].to_f + sl["calcTax2"].to_f)
            if tax_total == 0.0
              tax = 0.0
            end
            total += tax
            taxes << tax
          end
        end
      end
    end
    total = total.to_f.round(2)
    tax_total = tax_total.to_f.round(2)
    if total != tax_total
      difference = (tax_total - total).round(2)
      if difference != 0
        taxes[0] += difference
      end
      taxes[0] = taxes[0].round(2)
    end
    # round all taxes to nearest cent
    taxes.map { |t| format("%.2f", t).to_f.round(2) }
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

  # If any SaleLines.SaleLine.isSpecialOrder is true, then the SpecialOrderFlag should be set to 'Y'
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
    # MSC17061
    "N"
  end
end
