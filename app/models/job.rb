class Job < ApplicationRecord
  # Turn off single table inheritance
  self.inheritance_column = nil
  has_many :logs, foreign_key: "jobs_id", class_name: "AppLog"
  enum :status, [:created, :processing, :error, :complete, :paused], prefix: true
end
