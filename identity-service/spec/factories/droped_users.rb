FactoryBot.define do
  factory :droped_user do
    sequence(:name) { |n| "DropedUser#{n}" }

    # Формат имени: 3-27 символов, буквы/цифры/нижнее подчёркивание
    trait :custom_name do
      transient do
        custom_name { "CustomPlayer" }
      end
      name { custom_name }
    end
  end
end
