FactoryBot.define do
  factory :punishment_reason do
    punishment_type { "ban" }
    sequence(:description) { |n| "Punishment reason ##{n}" }
    sequence(:rule_number) { |n| n }
    price { Faker::Number.decimal(l_digits: 3, r_digits: 2) }

    trait :ban do
      punishment_type { "ban" }
    end

    trait :mute do
      punishment_type { "mute" }
    end

    trait :free do
      price { 0 }
    end
  end
end
