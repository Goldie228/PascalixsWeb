FactoryBot.define do
  factory :photo do
    association :gallery
    title { Faker::Lorem.sentence(word_count: 3).truncate(255) }

    # Вложение Active Storage (при build — build(:photo) валиден)
    after(:build) do |photo|
      unless photo.file.attached?
        photo.file.attach(
          io: StringIO.new("fake image content"),
          filename: "photo.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :with_custom_file do
      transient do
        file_content { "custom image content" }
        file_name { "custom_photo.png" }
        file_type { "image/png" }
      end
      after(:build) do |photo, evaluator|
        photo.file.attach(
          io: StringIO.new(evaluator.file_content),
          filename: evaluator.file_name,
          content_type: evaluator.file_type
        )
      end
    end
  end
end
