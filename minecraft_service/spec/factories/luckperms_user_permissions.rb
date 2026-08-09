FactoryBot.define do
  factory :luckperms_user_permission do
    sequence(:uuid) { |n| "a1b2c3d4-e5f6-7890-abcd-ef#{n.to_s.rjust(12, '0')}" }
    permission { "some.permission" }
    value { true }
    server { "global" }
    world { "global" }
    expiry { 0 }
    contexts { "{}" }

    trait :group_permission do
      sequence(:permission) { |n| "group.group_#{n}" }
    end

    trait :false_value do
      value { false }
    end
  end
end
