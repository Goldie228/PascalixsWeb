FactoryBot.define do
  factory :discord_account do
    sequence(:discord_id) { |n| n.to_s }
    username { Faker::Internet.username(specifier: 5..20, separators: ["_"]) }
    discriminator { Faker::Number.number(digits: 4).to_s }
    email { Faker::Internet.email }
    avatar { Faker::Internet.url(host: "cdn.discordapp.com", path: "/avatars/#{discord_id}/avatar.png") }

    # Создаём пользователя без зацикливания зависимостей
    after(:build) do |discord_account|
      if discord_account.user.nil?
        user = build(:user, role: build(:role))
        user.instance_variable_set(:@skip_discord_account, true)
        discord_account.user = user
      end
    end

    trait :with_avatar_file do
      after(:create) do |discord_account|
        discord_account.avatar_file.attach(
          io: StringIO.new("fake image content"),
          filename: "avatar.png",
          content_type: "image/png"
        )
      end
    end
  end
end
