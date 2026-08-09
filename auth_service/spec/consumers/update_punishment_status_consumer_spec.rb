require "rails_helper"

RSpec.describe UpdatePunishmentStatusConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  before do
    allow(UserDataProducer).to receive(:publish)
    redis_client = double("REDIS_CLIENT")
    allow(redis_client).to receive(:hset)
    allow(redis_client).to receive(:expire)
    allow(redis_client).to receive(:del)
    allow(redis_client).to receive(:hgetall).and_return({})
    stub_const("REDIS_CLIENT", redis_client)
    allow(MinecraftAccount).to receive(:find_by).and_return(nil)
    allow(consumer).to receive(:messages).and_return([])
  end

  describe "#consume" do
    context "with users having expired punishments" do
      let(:user) { create(:user) }
      let(:reason) { create(:punishment_reason, :ban) }
      let!(:expired_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: user,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: 1.day.ago)
      end

      it "deactivates expired punishments" do
        consumer.consume

        expect(expired_punishment.reload.active).to be false
      end

      it "publishes user data for each processed user" do
        consumer.consume

        expect(UserDataProducer).to have_received(:publish).with(user).at_least(:once)
      end
    end

    context "with users having active (non-expired) punishments" do
      let(:user) { create(:user) }
      let(:reason) { create(:punishment_reason, :ban) }
      let!(:active_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: user,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: 1.day.from_now)
      end

      it "does not deactivate active punishments" do
        consumer.consume

        expect(active_punishment.reload.active).to be true
      end

      it "still publishes user data" do
        consumer.consume

        expect(UserDataProducer).to have_received(:publish).with(user).at_least(:once)
      end
    end

    context "with users having permanent punishments (no expires_at)" do
      let(:user) { create(:user) }
      let(:reason) { create(:punishment_reason, :ban) }
      let!(:permanent_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: user,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: nil)
      end

      it "does not deactivate permanent punishments" do
        consumer.consume

        expect(permanent_punishment.reload.active).to be true
      end
    end

    context "with multiple users" do
      let!(:user1) { create(:user) }
      let!(:user2) { create(:user) }
      let(:reason) { create(:punishment_reason, :ban) }

      let!(:punishment1) do
        create(:users_punishment,
               user: user1,
               bad_user: user1,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: 1.day.ago)
      end

      let!(:punishment2) do
        create(:users_punishment,
               user: user2,
               bad_user: user2,
               punishment_reason: reason,
               type: "ban",
               active: true,
               expires_at: 1.hour.ago)
      end

      it "processes all users" do
        consumer.consume

        expect(UserDataProducer).to have_received(:publish).with(user1).at_least(:once)
        expect(UserDataProducer).to have_received(:publish).with(user2).at_least(:once)
      end

      it "deactivates all expired punishments" do
        consumer.consume

        expect(punishment1.reload.active).to be false
        expect(punishment2.reload.active).to be false
      end
    end

    context "with no users in the system" do
      it "completes without errors" do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when an error occurs for a user" do
      let!(:user) { create(:user) }

      it "continues processing other users" do
        allow(UserDataProducer).to receive(:publish).with(user).and_raise(StandardError, "boom")

        expect { consumer.consume }.not_to raise_error
      end

      it "logs the error" do
        allow(UserDataProducer).to receive(:publish).with(user).and_raise(StandardError, "boom")

        expect(Rails.logger).to receive(:error).with(/Ошибка при обновлении пользователя/)
        consumer.consume
      end
    end

    context "with already inactive punishments" do
      let(:user) { create(:user) }
      let(:reason) { create(:punishment_reason, :ban) }
      let!(:inactive_punishment) do
        create(:users_punishment,
               user: user,
               bad_user: user,
               punishment_reason: reason,
               type: "ban",
               active: false,
               expires_at: 1.day.ago)
      end

      it "does not attempt to re-deactivate already inactive punishments" do
        consumer.consume

        expect(inactive_punishment.reload.active).to be false
      end
    end
  end

  describe "BATCH_SIZE" do
    it "is set to 500" do
      expect(described_class::BATCH_SIZE).to eq(500)
    end
  end
end
