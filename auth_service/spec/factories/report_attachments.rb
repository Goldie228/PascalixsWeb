FactoryBot.define do
  factory :report_attachment do
    association :user_report
    filename { Faker::File.file_name(dir: "", ext: "jpg") }
    content_type { "image/jpeg" }
    file_size { Faker::Number.between(from: 1024, to: 5_000_000) }

    trait :image_jpeg do
      content_type { "image/jpeg" }
      filename { Faker::File.file_name(dir: "", ext: "jpg") }
    end

    trait :image_png do
      content_type { "image/png" }
      filename { Faker::File.file_name(dir: "", ext: "png") }
    end

    trait :video_mp4 do
      content_type { "video/mp4" }
      filename { Faker::File.file_name(dir: "", ext: "mp4") }
      file_size { Faker::Number.between(from: 1_000_000, to: 500_000_000) }
    end
  end
end
