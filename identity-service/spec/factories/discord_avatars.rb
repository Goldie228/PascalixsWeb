FactoryBot.define do
  factory :discord_avatar do
    status { "pending" }
    original_url { Faker::Internet.url(host: "cdn.discordapp.com", path: "/avatars/avatar.png") }

    # Ручное создание связей для избежания циклической зависимости
    # Фабрика user автоматически создаёт discord_account — циклическая зависимость
    # Поэтому создаём вручную
    after(:build) do |discord_avatar|
      if discord_avatar.discord_account.nil?
        # Пользователь с discord_account через skip_email_validation
        user = nil
        User.skip_email_validation do
          user = create(:user)
        end
        discord_avatar.discord_account = user.discord_account
      end
    end

    trait :pending do
      status { "pending" }
    end

    trait :approved do
      status { "approved" }
    end

    trait :rejected do
      status { "rejected" }
    end

    trait :with_file do
      after(:create) do |discord_avatar|
        discord_avatar.file.attach(
          io: StringIO.new("fake avatar image"),
          filename: "avatar.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :with_gif_file do
      after(:create) do |discord_avatar|
        discord_avatar.file.attach(
          io: StringIO.new("fake gif content"),
          filename: "avatar.gif",
          content_type: "image/gif"
        )
      end
    end
  end
end
