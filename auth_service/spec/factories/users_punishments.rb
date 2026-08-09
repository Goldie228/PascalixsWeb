FactoryBot.define do
  factory :users_punishment do
    user { build(:user) }
    bad_user { build(:user) }
    punishment_reason { build(:punishment_reason, punishment_type: "ban") }
    type { "ban" }
    issued_at { Time.current }
    duration { 86_400 } # 1 day in seconds
    expires_at { 1.day.from_now }
    active { true }
    withdrawal_price { nil }

    # punishment_type должен совпадать с типом причины
    after(:build) do |punishment|
      if punishment.punishment_reason
        punishment.type = punishment.punishment_reason.punishment_type
      end
    end

    trait :ban do
      type { "ban" }
      association :punishment_reason, punishment_type: "ban"
    end

    trait :mute do
      type { "mute" }
      association :punishment_reason, punishment_type: "mute"
    end

    trait :expired do
      active { false }
      expires_at { 1.day.ago }
    end

    trait :permanent do
      duration { nil }
      expires_at { nil }
    end
  end
end
