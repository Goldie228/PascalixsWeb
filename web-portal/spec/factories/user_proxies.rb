FactoryBot.define do
  factory :user_proxy, class: 'UserProxy' do
    transient do
      user_id { SecureRandom.uuid }
      current_user_id { nil }
      cached_data { {} }
    end

    # UserProxy — PORO, создаём через реальный конструктор
    initialize_with do
      new(
        { 'user_id' => user_id, 'cached' => cached_data },
        current_user_id: current_user_id
      )
    end

    trait :as_self do
      current_user_id { user_id }
    end

    trait :with_cached_email do
      cached_data { { 'email' => Faker::Internet.email } }
    end

    trait :with_cached_username do
      cached_data { { 'username' => Faker::Internet.username } }
    end
  end
end
