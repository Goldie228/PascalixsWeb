FactoryBot.define do
  factory :minecraft_account do
    sequence(:nickname) { |n| "Player_#{n}" }
    password { "Password1" }
    password_confirmation { "Password1" }

    # Создаём пользователя без зацикливания зависимостей
    after(:build) do |minecraft_account|
      if minecraft_account.user.nil?
        user = build(:user, role: build(:role))
        user.instance_variable_set(:@skip_discord_account, true)
        minecraft_account.user = user
      end
    end

    # Сложность пароля: 8-32 символа, минимум одна буква и одна цифра
    trait :with_custom_password do
      transient do
        custom_password { "Secure123" }
      end
      password { custom_password }
      password_confirmation { custom_password }
    end
  end
end
