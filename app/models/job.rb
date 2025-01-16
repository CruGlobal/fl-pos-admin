class Job < ApplicationRecord
  # Turn off single table inheritance
  self.inheritance_column = nil
  has_many :logs, foreign_key: "jobs_id", class_name: "AppLog", dependent: :destroy
  enum :status, [:created, :processing, :error, :complete, :paused], prefix: true, default: :created
end
