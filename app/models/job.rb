class Job < ApplicationRecord
  enum :status, [ :created, :processing, :error, :complete, :paused ]
end
