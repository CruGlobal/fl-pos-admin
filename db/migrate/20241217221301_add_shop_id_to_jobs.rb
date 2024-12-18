class AddShopIdToJobs < ActiveRecord::Migration[8.0]
  def change
    # Add shop_id as a bigint column to the jobs table. This is not a foreign key.
    add_column :jobs, :shop_id, :bigint
  end
end
