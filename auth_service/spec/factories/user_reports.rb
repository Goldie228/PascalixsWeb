FactoryBot.define do
  factory :user_report do
    association :reporter, factory: :user
    association :reported_user, factory: :user
    title { Faker::Lorem.sentence(word_count: 5).truncate(80) }
    description { Faker::Lorem.paragraph(sentence_count: 5).truncate(5000) }
    is_active { true }

    # reporter != reported_user
    after(:build) do |report|
      if report.reporter_id == report.reported_user_id
        report.reported_user = create(:user)
      end
    end

    trait :active do
      is_active { true }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
