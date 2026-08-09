FactoryBot.define do
  factory :user do
    role { build(:role) }
    about_me { Faker::Lorem.sentence(word_count: 10) }
    is_added { false }
    is_sponsor { false }
    time_zone { "UTC" }

    # Генерация UUID (БД требует строковый ID)
    before(:create) do |user|
      user.id = SecureRandom.uuid if user.id.blank?
    end

    # Email делегируется в discord_account — строим автоматически
    # Пропускаем если фабрика discord_account/minecraft_account уже строит
    # чтобы избежать циклической зависимости
    after(:build) do |user|
      next if user.instance_variable_get(:@skip_discord_account)
      user.discord_account ||= build(:discord_account, user: user)
    end

    trait :with_discord_account do
      after(:build) do |user|
        user.discord_account ||= build(:discord_account, user: user)
      end
    end

    trait :with_minecraft_account do
      after(:build) do |user|
        user.minecraft_account ||= build(:minecraft_account, user: user)
      end
    end

    trait :with_accounts do
      with_discord_account
      with_minecraft_account
    end

    trait :admin do
      association :role, factory: :role, name: "Admin"
    end

    trait :moderator do
      association :role, factory: :role, name: "Moderator"
    end

    trait :sponsor do
      is_sponsor { true }
    end

    trait :with_2fa do
      otp_required_for_login { true }
      otp_secret { User.generate_otp_secret }
    end
  end
end
