class AddInitialTables < ActiveRecord::Migration[8.0]
  def change
    create_table :jobs do |t|
      t.string :status
      t.string :event_code
      t.date :start_date
      t.date :end_date
      t.datetime :completed_at
      t.timestamps
    end

    create_table :logs do |t|
      t.text :content
      t.references :jobs, foreign_key: true
      t.timestamps
    end
  end
end
