FactoryBot.define do
  factory :user_punishment_appeal do
    association :punishment, factory: :users_punishment
    user_message { Faker::Lorem.paragraph(sentence_count: 3) }
    admin_comment { nil }
    status { "pending" }
    can_reappeal { true }

    trait :pending do
      status { "pending" }
    end

    trait :accepted do
      status { "accepted" }
      admin_comment { Faker::Lorem.sentence }
    end

    trait :rejected do
      status { "rejected" }
      admin_comment { Faker::Lorem.sentence }
      can_reappeal { false }
    end
  end
end
