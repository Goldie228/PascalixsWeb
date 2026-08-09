FactoryBot.define do
  factory :luckperms_group do
    sequence(:name) { |n| "group_#{n}" }
    color { "#FF5555" }

    trait :admin do
      name { "admin" }
      color { "#AA0000" }
    end

    trait :moderator do
      name { "moderator" }
      color { "#55FF55" }
    end

    trait :member do
      name { "member" }
      color { "#FFFFFF" }
    end

    trait :vip do
      name { "vip" }
      color { "#FFAA00" }
    end
  end
end
