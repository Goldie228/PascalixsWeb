FactoryBot.define do
  factory :user do
    id { SecureRandom.uuid }
    email { Faker::Internet.unique.email }
    username { Faker::Internet.unique.username(specifier: 5..20) }
    is_registered { true }

    # web_service использует nulldb — только build стратегия.
    # Фабрики создают in-memory объекты — нельзя сохранить.

    trait :without_registration do
      is_registered { false }
    end

    trait :with_minecraft_account do
      after(:build) do |user|
        # Модель MinecraftAccount может не существовать — лёгкая заглушка
        user.association(:minecraft_account, strategy: :build) if defined?(MinecraftAccount)
      end
    end
  end
end
