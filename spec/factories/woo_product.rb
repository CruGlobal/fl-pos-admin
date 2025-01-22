FactoryBot.define do
  factory :woo_product do
    sku { Faker::Alphanumeric.alpha(number: 10) }
    product_id { Faker::Number.number(digits: 10) }
    status { "active" }
    type { "simple" }
  end
end
