FactoryBot.define do
  factory :gallery do
    title { Faker::Lorem.sentence(word_count: 3).truncate(255) }
    description { Faker::Lorem.paragraph(sentence_count: 2).truncate(4096) }
    published { false }

    trait :published do
      published { true }
      # Опубликованная галерея требует хотя бы одно фото
      # before(:create) добавляет фото до валидации
      before(:create) do |gallery|
        gallery.photos << build(:photo, gallery: gallery) if gallery.photos.empty?
      end
    end

    trait :with_photos do
      transient do
        photos_count { 3 }
      end
      after(:create) do |gallery, evaluator|
        create_list(:photo, evaluator.photos_count, gallery: gallery)
      end
    end
  end
end
