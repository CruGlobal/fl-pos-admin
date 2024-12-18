class AppLog < ApplicationRecord
  self.table_name = 'logs'
  # Turn off single table inheritance
  self.inheritance_column = nil
  belongs_to :jobs, foreign_key: 'jobs_id', class_name: 'Job'
end
