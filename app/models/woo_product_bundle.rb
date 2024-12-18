class WooProductBundle < ApplicationRecord
  self.table_name = 'woo_product_bundles'
  # Turn off single table inheritance
  self.inheritance_column = nil
  belongs_to :woo_products, foreign_key: 'product_id', class_name: 'WooProduct'
end
