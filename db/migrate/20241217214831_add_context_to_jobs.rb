class AddContextToJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :jobs, :context, :jsonb, null: false, default: {}
    add_index :jobs, :context, using: :gin
  end
end
