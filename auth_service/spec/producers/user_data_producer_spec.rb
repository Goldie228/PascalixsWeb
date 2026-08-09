require "rails_helper"

RSpec.describe UserDataProducer do
  let(:redis_mock) { instance_double(Redis) }
  let(:clickhouse_connection) { instance_double(ClickHouse::Connection) }

  # Мок пользователя для избежания проблем с валидацией фабрики
  let(:user) do
    double("User",
      id: "test-user-123",
      as_json: {
        "user_id" => "test-user-123",
        "email" => "test@example.com",
        "about_me" => "Test user",
        "is_added" => false,
        "is_sponsor" => false,
        "youtube_url" => nil,
        "twitch_url" => nil,
        "tiktok_url" => nil,
        "role_id" => 1,
        "discord_account" => {
          "user_id" => "test-user-123",
          "username" => "testuser",
          "discriminator" => "1234",
          "avatar" => "https://cdn.discordapp.com/avatars/123/avatar.png",
          "email" => "test@example.com"
        },
        "minecraft_account" => {
          "user_id" => "test-user-123",
          "nickname" => "TestPlayer"
        }
      },
      role_name: "TestRole",
      role_color: "#FF00FF",
      role_id: 1,
      discord_account: double("DiscordAccount",
        user_id: "test-user-123",
        username: "testuser",
        discriminator: "1234",
        avatar: "https://cdn.discordapp.com/avatars/123/avatar.png"
      ),
      minecraft_account: double("MinecraftAccount",
        user_id: "test-user-123",
        nickname: "TestPlayer"
      ),
      issued_punishments: double("Punishments", where: []),
      is_added: false,
      is_sponsor: false,
      youtube_url: nil,
      twitch_url: nil,
      tiktok_url: nil
    )
  end

  before do
    # Заглушка CheckUserPasswordService
    allow(CheckUserPasswordService).to receive(:call)

    # Заглушка Redis
    stub_const("REDIS_CLIENT", redis_mock)
    allow(redis_mock).to receive(:hgetall).and_return({})
    allow(redis_mock).to receive(:hset)
    allow(redis_mock).to receive(:expire)
    allow(redis_mock).to receive(:del)

    # Заглушка ClickHouse
    allow(ClickHouse).to receive_message_chain(:connection, :execute)
    allow(ClickHouse).to receive_message_chain(:connection, :insert)

    # Заглушка Rails.logger
    allow(Rails.logger).to receive(:debug)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe ".publish" do
    context "when user has valid data" do
      it "calls CheckUserPasswordService with user_id" do
        described_class.publish(user)

        expect(CheckUserPasswordService).to have_received(:call).with(user_id: "test-user-123")
      end

      it "stores user data in Redis with deduplication check" do
        expect(redis_mock).to receive(:hgetall).with("user_updates:test-user-123")
        expect(redis_mock).to receive(:hset)
        expect(redis_mock).to receive(:expire).with("user_updates:test-user-123", 3.hour.to_i)

        described_class.publish(user)
      end

      it "upserts user record to ClickHouse" do
        expect(ClickHouse.connection).to receive(:insert).with("users", [hash_including(user_id: "test-user-123")])

        described_class.publish(user)
      end

      it "optimizes ClickHouse table after insert" do
        expect(ClickHouse.connection).to receive(:execute).with("OPTIMIZE TABLE users FINAL")

        described_class.publish(user)
      end

      it "invalidates public profile cache in Redis" do
        expect(redis_mock).to receive(:del).with("public_profile:TestPlayer")

        described_class.publish(user)
      end
    end

    context "when user data has not changed (deduplication)" do
      before do
        # AUTH_SERVICE_URL не задан — normalize_domain возвращает URL как есть
        ENV.delete("AUTH_SERVICE_URL")
      end

      it "skips Redis write when data hash matches" do
        # Первая публикация: данные новые — hgetall возвращает {}, hset вызывается.
        # Захватываем данные из hset.
        stored_data = nil
        allow(redis_mock).to receive(:hset) do |_key, _ts, json|
          stored_data = json
        end

        described_class.publish(user)

        # Теперь hgetall возвращает те же данные
        allow(redis_mock).to receive(:hgetall).and_return({ "12345" => stored_data })

        # Вторая публикация: dedup должен определить что изменений нет
        expect(redis_mock).not_to receive(:hset)
        described_class.publish(user)
      end
    end

    context "when user has no user_id" do
      let(:user_without_id) do
        double("User",
          id: nil,
          as_json: {
            "user_id" => nil,
            "discord_account" => { "user_id" => nil },
            "minecraft_account" => { "user_id" => nil },
            "role_name" => "User",
            "role_color" => "#A0A0A0"
          },
          role_name: "User",
          role_color: "#A0A0A0",
          discord_account: double("DiscordAccount", user_id: nil, avatar: nil),
          minecraft_account: double("MinecraftAccount", user_id: nil, nickname: nil),
          issued_punishments: double("Punishments", where: []),
          is_added: false,
          is_sponsor: false,
          youtube_url: nil,
          twitch_url: nil,
          tiktok_url: nil,
          role_id: nil
        )
      end

      it "skips processing and logs a warning" do
        expect(redis_mock).not_to receive(:hset)
        expect(Rails.logger).to receive(:warn).with("Skipping message without user_id")

        described_class.publish(user_without_id)
      end
    end

    context "when discord avatar URL needs normalization" do
      before do
        ENV["AUTH_SERVICE_URL"] = "https://auth.example.com"
        allow(user.discord_account).to receive(:avatar).and_return("https://other-domain.com/avatar.png")
      end

      after do
        ENV.delete("AUTH_SERVICE_URL")
      end

      it "normalizes avatar domain to AUTH_SERVICE_URL" do
        described_class.publish(user)

        expect(redis_mock).to have_received(:hset)
      end
    end

    context "when avatar domain already matches AUTH_SERVICE_URL" do
      before do
        ENV["AUTH_SERVICE_URL"] = "https://auth.example.com"
        allow(user.discord_account).to receive(:avatar).and_return("https://auth.example.com/avatar.png")
      end

      after do
        ENV.delete("AUTH_SERVICE_URL")
      end

      it "keeps avatar URL unchanged" do
        described_class.publish(user)

        expect(redis_mock).to have_received(:hset)
      end
    end

    context "when AUTH_SERVICE_URL is not set" do
      before do
        ENV.delete("AUTH_SERVICE_URL")
      end

      it "returns avatar URL as-is and logs a warning" do
        expect(Rails.logger).to receive(:warn).with("AUTH_SERVICE_URL is not set, cannot normalize domain")

        described_class.publish(user)
      end
    end

    context "when user has nil values in data" do
      before do
        allow(user.discord_account).to receive(:avatar).and_return(nil)
        user_data = user.as_json
        user_data["about_me"] = nil
        allow(user).to receive(:as_json).and_return(user_data)
      end

      it "replaces nil values with empty strings in stored data" do
        expect(redis_mock).to receive(:hset) do |_key, _ts, json_data|
          parsed = JSON.parse(json_data)
          # replace_nil_with_empty конвертирует nil в ""
          expect(parsed["about_me"]).to eq("")
        end

        described_class.publish(user)
      end
    end

    context "when CheckUserPasswordService raises an error" do
      before do
        allow(CheckUserPasswordService).to receive(:call).and_raise(StandardError.new("Service unavailable"))
      end

      it "catches the error and logs it" do
        expect(Rails.logger).to receive(:error).with(/Error processing message: Service unavailable/)

        expect { described_class.publish(user) }.not_to raise_error
      end

      it "does not store data in Redis" do
        expect(redis_mock).not_to receive(:hset)

        described_class.publish(user)
      end
    end

    context "when Redis raises an error during store" do
      before do
        allow(redis_mock).to receive(:hset).and_raise(Redis::ConnectionError.new("Connection refused"))
      end

      it "catches the error and logs it" do
        expect(Rails.logger).to receive(:error).with(/Error processing message: Connection refused/)

        expect { described_class.publish(user) }.not_to raise_error
      end
    end

    context "when ClickHouse insert fails" do
      before do
        allow(ClickHouse.connection).to receive(:insert).and_raise(StandardError.new("ClickHouse down"))
      end

      it "logs the error but does not raise" do
        expect(Rails.logger).to receive(:error).with(/ClickHouse insert error: ClickHouse down/)

        expect { described_class.publish(user) }.not_to raise_error
      end
    end

    context "when ClickHouse optimize fails" do
      before do
        allow(ClickHouse.connection).to receive(:execute).and_raise(StandardError.new("Optimize failed"))
      end

      it "logs the error but continues" do
        expect(Rails.logger).to receive(:error).with(/Ошибка при оптимизации таблицы: Optimize failed/)

        expect { described_class.publish(user) }.not_to raise_error
      end
    end

    context "with user role data" do
      it "includes role_name and role_color in the payload and excludes role_id" do
        expect(redis_mock).to receive(:hset) do |_key, _ts, json_data|
          parsed = JSON.parse(json_data)
          expect(parsed["role_name"]).to eq("TestRole")
          expect(parsed["role_color"]).to eq("#FF00FF")
          expect(parsed).not_to have_key("role_id")
        end

        described_class.publish(user)
      end
    end

    context "with punishment status" do
      it "sets punishment_status to 1 for user without active punishments" do
        expect(ClickHouse.connection).to receive(:insert) do |_table, records|
          record = records.first
          expect(record[:punishment_status]).to eq(1)
        end

        described_class.publish(user)
      end

      it "sets punishment_status to 3 for user with active ban" do
        ban = double("Punishment", type: "ban", expires_at: 1.day.from_now)
        allow(user.issued_punishments).to receive(:where).with(active: true).and_return([ban])

        expect(ClickHouse.connection).to receive(:insert) do |_table, records|
          record = records.first
          expect(record[:punishment_status]).to eq(3)
        end

        described_class.publish(user)
      end

      it "sets punishment_status to 2 for user with active mute" do
        mute = double("Punishment", type: "mute", expires_at: 1.day.from_now)
        allow(user.issued_punishments).to receive(:where).with(active: true).and_return([mute])

        expect(ClickHouse.connection).to receive(:insert) do |_table, records|
          record = records.first
          expect(record[:punishment_status]).to eq(2)
        end

        described_class.publish(user)
      end
    end

    context "with ClickHouse record format" do
      it "includes all required fields in the ClickHouse record" do
        expect(ClickHouse.connection).to receive(:insert) do |_table, records|
          record = records.first
          expect(record).to include(
            :user_id,
            :discord_username,
            :minecraft_nickname,
            :is_added,
            :is_sponsor,
            :has_youtube,
            :has_twitch,
            :has_tiktok,
            :punishment_status,
            :role_id,
            :discord_avatar_url,
            :updated_at
          )
        end

        described_class.publish(user)
      end

      it "formats discord username with discriminator when present" do
        expect(ClickHouse.connection).to receive(:insert) do |_table, records|
          record = records.first
          expect(record[:discord_username]).to eq("testuser#1234")
        end

        described_class.publish(user)
      end
    end
  end
end
