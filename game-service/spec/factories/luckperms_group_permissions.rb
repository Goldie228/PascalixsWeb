FactoryBot.define do
  factory :luckperms_group_permission do
    sequence(:name) { |n| "group_#{n}" }
    permission { "some.permission" }
    value { true }
    server { "global" }
    world { "global" }
    expiry { 0 }
    contexts { "{}" }

    trait :displayname do
      sequence(:permission) { |n| "displayname.Display Name #{n}" }
    end

    trait :weight do
      sequence(:permission) { |n| "weight.#{n * 10}" }
    end

    trait :dontshow do
      permission { "group.dontshow" }
    end

    trait :false_value do
      value { false }
    end
  end
end
