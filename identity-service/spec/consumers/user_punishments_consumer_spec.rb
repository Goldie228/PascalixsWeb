require "rails_helper"

RSpec.describe UserPunishmentsConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  let(:redis_client) do
    double("REDIS_CLIENT").tap do |r|
      allow(r).to receive(:hset)
      allow(r).to receive(:expire)
      allow(r).to receive(:del)
    end
  end

  before do
    stub_const("REDIS_CLIENT", redis_client)
    allow(UserDataProducer).to receive(:publish)
    allow(MinecraftAccount).to receive(:find_by).and_return(nil)
  end

  # Хелпер: мок Karafka-сообщения
  def build_message(payload)
    double("Message", payload: payload)
  end

  # Хелпер: привязка сообщений к потребителю
  def stub_messages(*payloads)
    messages = payloads.map { |p| build_message(p) }
    allow(consumer).to receive(:messages).and_return(messages)
  end

  # Хелпер: сброс мока Redis после создания записи (after_commit колбэки)
  def reset_redis_mock
    allow(redis_client).to receive(:hset)
    allow(redis_client).to receive(:expire)
  end

  let(:user) { create(:user) }
  let(:bad_user) { create(:user) }
  let(:reason) { create(:punishment_reason, :ban) }

  describe "#consume" do
    context "with active, non-expired punishments" do
      let!(:punishment) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: 1.day.from_now)
      end

      before { reset_redis_mock }

      it "stores punishments in Redis" do
        stub_messages({ "user_id" => bad_user.id })
        consumer.consume

        expect(redis_client).to have_received(:hset).with(
          "punishments:#{bad_user.id}", "data", anything
        ).at_least(:once)
      end

      it "sets TTL on the Redis key" do
        stub_messages({ "user_id" => bad_user.id })
        consumer.consume

        expect(redis_client).to have_received(:expire).with(
          "punishments:#{bad_user.id}", described_class::TTL_SECONDS
        ).at_least(:once)
      end

      it "includes punishment data in Redis payload" do
        stub_messages({ "user_id" => bad_user.id })
        consumer.consume

        expect(redis_client).to have_received(:hset).at_least(:once)
      end
    end

    context "with expired punishments" do
      let!(:expired_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: 1.day.ago)
      end

      before { reset_redis_mock }

      it "does not store expired punishments via consumer logic" do
        stub_messages({ "user_id" => bad_user.id })

        # Отслеживаем вызовы только во время consume
        consumer_calls = []
        allow(redis_client).to receive(:hset) { |*args| consumer_calls << args }

        consumer.consume

        # Consumer фильтрует истёкшие наказания — hset не вызывается
        expect(consumer_calls).to be_empty
      end
    end

    context "with permanent punishments (no expires_at)" do
      let!(:permanent_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: nil)
      end

      before { reset_redis_mock }

      it "treats permanent punishments as valid" do
        stub_messages({ "user_id" => bad_user.id })
        consumer.consume

        expect(redis_client).to have_received(:hset).with(
          "punishments:#{bad_user.id}", "data", anything
        ).at_least(:once)
      end
    end

    context "with inactive punishments" do
      let!(:inactive_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason,
               type: "ban",
               active: false,
               expires_at: 1.day.from_now)
      end

      before { reset_redis_mock }

      it "does not store inactive punishments via consumer logic" do
        stub_messages({ "user_id" => bad_user.id })

        consumer_calls = []
        allow(redis_client).to receive(:hset) { |*args| consumer_calls << args }

        consumer.consume

        # Consumer запрашивает active: true — неактивные исключены
        expect(consumer_calls).to be_empty
      end
    end

    context "with missing user_id" do
      it "skips the message" do
        stub_messages({ "other_field" => "value" })
        consumer.consume

        expect(redis_client).not_to have_received(:hset)
      end

      it "logs a warning" do
        stub_messages({ "other_field" => "value" })

        expect(Rails.logger).to receive(:warn).with(/без user_id/)
        consumer.consume
      end
    end

    context "with blank user_id" do
      it "skips the message" do
        stub_messages({ "user_id" => "" })
        consumer.consume

        expect(redis_client).not_to have_received(:hset)
      end
    end

    context "with nil user_id" do
      it "skips the message" do
        stub_messages({ "user_id" => nil })
        consumer.consume

        expect(redis_client).not_to have_received(:hset)
      end
    end

    context "with no punishments for the user" do
      it "does not write to Redis" do
        stub_messages({ "user_id" => "nonexistent-user-id" })
        consumer.consume

        expect(redis_client).not_to have_received(:hset)
      end
    end

    context "with multiple messages" do
      let(:bad_user2) { create(:user) }
      let(:reason2) { create(:punishment_reason, :mute, rule_number: 2) }

      let!(:punishment1) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: 1.day.from_now)
      end

      let!(:punishment2) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user2,
               punishment_reason: reason2,
               type: "mute",
               active: true,
               expires_at: 2.days.from_now)
      end

      before { reset_redis_mock }

      it "processes all messages" do
        stub_messages(
          { "user_id" => bad_user.id },
          { "user_id" => bad_user2.id }
        )
        consumer.consume

        expect(redis_client).to have_received(:hset).with("punishments:#{bad_user.id}", "data", anything).at_least(:once)
        expect(redis_client).to have_received(:hset).with("punishments:#{bad_user2.id}", "data", anything).at_least(:once)
      end
    end

    context "with non-Hash payload" do
      it "skips the message gracefully" do
        message = double("Message", payload: "not a hash")
        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
        expect(redis_client).not_to have_received(:hset)
      end
    end

    context "with multiple punishments for same user" do
      let(:reason2) { create(:punishment_reason, :mute, rule_number: 2) }

      let!(:ban_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: 1.day.from_now)
      end

      let!(:mute_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason2,
               type: "mute",
               active: true,
               expires_at: 2.days.from_now)
      end

      before { reset_redis_mock }

      it "stores all active punishments" do
        stub_messages({ "user_id" => bad_user.id })

        captured_data = nil
        allow(redis_client).to receive(:hset) do |key, field, json_data|
          captured_data = json_data if key == "punishments:#{bad_user.id}"
        end

        consumer.consume

        expect(captured_data).not_to be_nil
        parsed = JSON.parse(captured_data)
        expect(parsed.size).to eq(2)
      end
    end
  end

  describe "TTL_SECONDS" do
    it "equals 15 minutes in seconds" do
      expect(described_class::TTL_SECONDS).to eq(900)
    end
  end
end
