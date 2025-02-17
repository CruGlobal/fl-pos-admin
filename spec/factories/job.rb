FactoryBot.define do
  factory :job do
    type { "WOO_IMPORT" }
    status { "created" }
    start_date { Date.today.last_week(:thursday) }
    end_date { Date.today.last_week(:thursday) + 4.days }
    event_code { "1234" }
  end
end
