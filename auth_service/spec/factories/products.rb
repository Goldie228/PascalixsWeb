FactoryBot.define do
  factory :product do
    sequence(:product_type) { |n| "product_type_#{n}" }
    price { Faker::Number.decimal(l_digits: 2, r_digits: 2) }

    trait :free do
      price { 0 }
    end

    trait :premium do
      price { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    end
  end
end
