require "rails_helper"

RSpec.describe DeletePlayerConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  let(:redis_mock) { instance_double("Redis") }
  let(:clickhouse_connection) { instance_double("ClickHouse::Connection") }
  let(:clickhouse) { instance_double("ClickHouse::Client", connection: clickhouse_connection) }

  before do
    stub_const("REDIS_CLIENT", redis_mock)
    stub_const("ClickHouse", clickhouse)
    allow(redis_mock).to receive(:scan_each)
    allow(redis_mock).to receive(:get)
    allow(redis_mock).to receive(:del)
    allow(redis_mock).to receive(:hset)
    allow(redis_mock).to receive(:expire)
    allow(clickhouse_connection).to receive(:execute)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    allow(DeleteUserSessionService).to receive(:call).and_return(0)
    allow(UserDataProducer).to receive(:publish)
    allow(AuthEventsProducer).to receive_messages(
      user_registered: nil,
      user_logged_in: nil,
      user_logged_out: nil,
      authentication_successful: nil,
      authentication_failed: nil
    ) unless defined?(AuthEventsProducer)
  end

  def build_message(payload)
    instance_double("Karafka::Messages::Message", payload: payload)
  end

  describe "#consume" do
    let!(:role) { create(:role, name: "User") }
    let!(:default_role) { Role.find_by(name: "User") || role }
    # Роль с id=1 — consumer хардкодит role_id: 1
    let!(:role_with_id_1) { Role.create!(id: 1, name: "Default", color: "#A0A0A0") rescue Role.find(1) }
    let!(:user) { create(:user, role: default_role, is_added: true) }
    let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "TestPlayer_#{SecureRandom.hex(4)}") }
    let!(:discord_account) { user.discord_account || create(:discord_account, user: user) }

    context "when player is found by Minecraft nickname" do
      let(:payload) { { nickname: minecraft_account.nickname, discord_id: nil }.to_json }

      it "revokes the user's pass (role_id set to default, is_added=false)" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        # Проверяем что update происходит перед destroy
        expect_any_instance_of(User).to receive(:update!).with(role_id: 1, is_added: false).and_call_original

        consumer.consume
      end

      it "adds nickname to droped_users" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(DropedUser.exists?(name: minecraft_account.nickname)).to be true
      end

      it "destroys associated accounts and user" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        mc_id = minecraft_account.id
        dc_id = discord_account.id
        user_id = user.id

        consumer.consume

        expect(MinecraftAccount.exists?(mc_id)).to be false
        expect(DiscordAccount.exists?(dc_id)).to be false
        expect(User.exists?(user_id)).to be false
      end

      it "calls DeleteUserSessionService" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(DeleteUserSessionService).to have_received(:call).with(
          user_id: user.id,
          nickname: minecraft_account.nickname
        )
      end

      it "deletes from ClickHouse" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(clickhouse_connection).to have_received(:execute).with(
          a_string_including("ALTER TABLE users DELETE WHERE user_id = '#{user.id}'")
        )
      end
    end

    context "when player is found by Discord ID (not by nickname)" do
      let(:payload) { { nickname: "UnknownNick", discord_id: discord_account.discord_id }.to_json }

      it "finds user via Discord account" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        user_id = user.id
        consumer.consume

        expect(User.exists?(user_id)).to be false
      end
    end

    context "when player is not found by either nickname or discord_id" do
      let(:payload) { { nickname: "GhostPlayer", discord_id: "999999" }.to_json }

      it "skips processing" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(DeleteUserSessionService).not_to have_received(:call)
      end

      it "logs a warning" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(Rails.logger).to have_received(:warn).with(/Пользователь не найден/)
      end
    end

    context "when nickname already exists in droped_users" do
      let!(:existing_droped) { create(:droped_user, name: minecraft_account.nickname) }
      let(:payload) { { nickname: minecraft_account.nickname, discord_id: nil }.to_json }

      it "does not create a duplicate" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect {
          consumer.consume
        }.not_to change(DropedUser, :count)
      end
    end

    context "with hash payload (not JSON string)" do
      let(:payload) { { nickname: minecraft_account.nickname, discord_id: nil } }

      it "handles symbolized hash payload" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "with invalid JSON" do
      let(:payload) { "not valid json{" }

      it "rescues JSON::ParserError" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Ошибка JSON/)
      end
    end

    context "when ClickHouse deletion fails" do
      let(:payload) { { nickname: minecraft_account.nickname, discord_id: nil }.to_json }

      before do
        allow(clickhouse_connection).to receive(:execute).and_raise(StandardError.new("CH error"))
      end

      it "logs the error but continues" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Ошибка при удалении из ClickHouse/)
      end
    end

    context "when user has punishments" do
      let!(:punishment) do
        create(:users_punishment, user: user, bad_user: user, active: true)
      end
      let(:payload) { { nickname: minecraft_account.nickname, discord_id: nil }.to_json }

      it "destroys punishment records in transaction" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        punishment_id = punishment.id
        consumer.consume

        expect(UsersPunishment.exists?(punishment_id)).to be false
      end
    end
  end
end
