class ChangeJobStatusToInteger < ActiveRecord::Migration[8.0]
  def change
    change_column :jobs, :status, :integer, using: 'status::integer'
  end
end
