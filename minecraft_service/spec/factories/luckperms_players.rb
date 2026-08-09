FactoryBot.define do
  factory :luckperms_player do
    sequence(:uuid) { |n| "a1b2c3d4-e5f6-7890-abcd-ef#{n.to_s.rjust(12, '0')}" }
    sequence(:username) { |n| "Steve_#{n}" }
    primary_group { "default" }

    trait :admin do
      primary_group { "admin" }
    end

    trait :moderator do
      primary_group { "moderator" }
    end
  end
end
