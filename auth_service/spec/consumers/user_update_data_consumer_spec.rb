require "rails_helper"

RSpec.describe UserUpdateDataConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  let(:clickhouse_connection) { instance_double("ClickHouse::Connection") }
  let(:clickhouse) { instance_double("ClickHouse::Client", connection: clickhouse_connection) }

  before do
    stub_const("ClickHouse", clickhouse)
    allow(clickhouse_connection).to receive(:execute)
    allow(clickhouse_connection).to receive(:insert)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:debug)
    allow(UserDataProducer).to receive(:publish)
  end

  def build_message(payload = "{}")
    instance_double("Karafka::Messages::Message", payload: payload)
  end

  describe "#consume" do
    context "when ClickHouse truncate succeeds" do
      it "truncates the users table" do
        allow(consumer).to receive(:messages).and_return([build_message])

        consumer.consume

        expect(clickhouse_connection).to have_received(:execute).with("TRUNCATE TABLE users")
      end
    end

    context "when there are users to sync" do
      let!(:role) { create(:role, name: "User") }
      let!(:user) { create(:user, role: role) }
      let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "SyncPlayer_#{SecureRandom.hex(4)}") }
      let!(:discord_account) { user.discord_account || create(:discord_account, user: user) }

      before do
        allow(consumer).to receive(:messages).and_return([build_message])
      end

      it "inserts user records into ClickHouse" do
        consumer.consume

        expect(clickhouse_connection).to have_received(:insert).with("users", anything)
      end

      it "builds records with expected fields" do
        consumer.consume

        expect(clickhouse_connection).to have_received(:insert) do |table, records|
          expect(table).to eq("users")
          expect(records).to be_an(Array)
          expect(records.first).to include(
            user_id: user.id.to_s,
            minecraft_nickname: user.minecraft_account.nickname
          )
        end
      end
    end

    context "when there are no users" do
      it "does not insert any records" do
        allow(consumer).to receive(:messages).and_return([build_message])

        consumer.consume

        expect(clickhouse_connection).not_to have_received(:insert)
      end
    end

    context "when truncate fails" do
      before do
        allow(clickhouse_connection).to receive(:execute).and_raise(StandardError.new("connection refused"))
        allow(consumer).to receive(:messages).and_return([build_message])
      end

      it "logs the error and returns early" do
        consumer.consume

        expect(Rails.logger).to have_received(:error).with(/Ошибка при очистке таблицы users/)
        expect(clickhouse_connection).not_to have_received(:insert)
      end
    end

    context "when insert fails for a batch" do
      let!(:role) { create(:role, name: "User") }
      let!(:user) { create(:user, role: role) }
      let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "FailPlayer_#{SecureRandom.hex(4)}") }

      before do
        allow(consumer).to receive(:messages).and_return([build_message])
        allow(clickhouse_connection).to receive(:insert).and_raise(StandardError.new("insert failed"))
      end

      it "logs the error but continues" do
        expect { consumer.consume }.not_to raise_error
        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end

    context "with user having punishment" do
      let!(:role) { create(:role, name: "User") }
      let!(:user) { create(:user, role: role) }
      let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "PunishPlayer_#{SecureRandom.hex(4)}") }
      let!(:punishment) do
        create(:users_punishment, :ban, user: user, bad_user: user, active: true, expires_at: 1.day.from_now)
      end

      before do
        allow(consumer).to receive(:messages).and_return([build_message])
      end

      it "includes punishment_status in the record" do
        consumer.consume

        expect(clickhouse_connection).to have_received(:insert) do |table, records|
          record = records.first
          expect(record[:punishment_status]).to eq(3) # ban = 3
        end
      end
    end

    context "with user having discord account with discriminator" do
      let!(:role) { create(:role, name: "User") }
      let!(:user) { create(:user, role: role) }
      let!(:discord_account) { user.discord_account || create(:discord_account, user: user) }

      before do
        allow(consumer).to receive(:messages).and_return([build_message])
      end

      it "formats discord name with discriminator" do
        consumer.consume

        expect(clickhouse_connection).to have_received(:insert) do |table, records|
          record = records.first
          dc = user.discord_account
          expect(record[:discord_username]).to eq("#{dc.username}##{dc.discriminator}")
        end
      end
    end
  end
end
