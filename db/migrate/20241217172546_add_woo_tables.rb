class AddWooTables < ActiveRecord::Migration[8.0]
  def change
    create_table :woo_products do |t|
      t.string :type
      t.bigint :status
      t.string :sku
      t.timestamps
    end

    create_table :woo_product_bundles do |t|
      t.references :woo_products, foreign_key: true, column: :product_id
      t.bigint :product_id
      t.bigint :bundled_product_id
      t.bigint :quantity_default
      t.timestamps
    end
  end
end
