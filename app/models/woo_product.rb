class WooProduct < ApplicationRecord
  # Disable single table inheritance
  self.inheritance_column = nil
  has_many :woo_product_bundles, foreign_key: :product_id, dependent: :destroy
end
