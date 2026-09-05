FactoryBot.define do
  factory :purchase do
    id { SecureRandom.uuid }
    purchaser { build(:user) }
    purchase_type { "pass_purchase" }
    amount { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    currency { "BYN" }
    status { "pending" }
    metadata { {} }

    # Для pass_purchase и sponsor target по умолчанию = purchaser
    after(:build) do |purchase|
      if purchase.type_pass_purchase? || purchase.type_sponsor?
        purchase.target_user_id ||= purchase.purchaser_user_id
      end
    end

    trait :pass_purchase do
      purchase_type { "pass_purchase" }
      after(:build) { |p| p.target_user_id ||= p.purchaser_user_id }
    end

    trait :pass_gift do
      purchase_type { "pass_gift" }
      association :target, factory: :user
      after(:build) { |p| p.target_user_id ||= 'fake-target-id' }
    end

    trait :sponsor do
      purchase_type { "sponsor" }
      after(:build) { |p| p.target_user_id ||= p.purchaser_user_id }
    end

    trait :unban do
      purchase_type { "unban" }
      association :target, factory: :user
      association :punishment, factory: [:users_punishment, :ban]
    end

    trait :unmute do
      purchase_type { "unmute" }
      association :target, factory: :user
      association :punishment, factory: [:users_punishment, :mute]
    end

    trait :approved do
      status { "approved" }
    end

    trait :rejected do
      status { "rejected" }
      review_comment { Faker::Lorem.sentence }
    end

    trait :with_receipt do
      after(:create) do |purchase|
        purchase.receipt.attach(
          io: StringIO.new("fake receipt image"),
          filename: "receipt.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end
