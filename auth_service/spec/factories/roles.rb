FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "Role_#{n}" }
    color { Faker::Color.hex_color }

    trait :admin do
      name { "Admin" }
      color { "#FF0000" }
    end

    trait :moderator do
      name { "Moderator" }
      color { "#00FF00" }
    end

    trait :user do
      name { "User" }
      color { "#A0A0A0" }
    end
  end
end
