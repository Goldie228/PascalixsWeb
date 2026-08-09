require "rails_helper"

RSpec.describe CancelPunishmentConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  before do
    allow(UserDataProducer).to receive(:publish)
    redis_client = double("REDIS_CLIENT")
    allow(redis_client).to receive(:hset)
    allow(redis_client).to receive(:expire)
    allow(redis_client).to receive(:del)
    stub_const("REDIS_CLIENT", redis_client)
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

  let(:user) { create(:user) }
  let(:bad_user) { create(:user) }
  let(:minecraft_account) { create(:minecraft_account, user: user, nickname: "TestPlayer") }
  let(:reason) { create(:punishment_reason, :ban) }
  let(:issued_at) { Time.current }
  let(:punishment) do
    create(:users_punishment,
           user: user,
           bad_user: bad_user,
           punishment_reason: reason,
           type: "ban",
           issued_at: issued_at,
           active: true)
  end

  let(:valid_payload) do
    { nickname: "TestPlayer", issued_at: issued_at.iso8601 }
  end

  describe "#consume" do
    context "with a valid payload" do
      before do
        minecraft_account
        punishment
      end

      it "deactivates the matching punishment" do
        stub_messages(valid_payload)
        consumer.consume

        expect(punishment.reload.active).to be false
      end

      it "finds punishment within the same minute" do
        # issued_at смещён, но в пределах минуты
        payload = { nickname: "TestPlayer", issued_at: (issued_at + 10.seconds).iso8601 }
        stub_messages(payload)
        consumer.consume

        expect(punishment.reload.active).to be false
      end

      it "handles payload as JSON string" do
        stub_messages(valid_payload.to_json)
        consumer.consume

        expect(punishment.reload.active).to be false
      end

      it "handles payload with string keys" do
        stub_messages(valid_payload.stringify_keys)
        consumer.consume

        expect(punishment.reload.active).to be false
      end
    end

    context "with missing required keys" do
      it "skips when nickname is missing" do
        stub_messages({ issued_at: issued_at.iso8601 })

        expect { consumer.consume }.not_to change { punishment&.reload&.active }
      end

      it "skips when issued_at is missing" do
        stub_messages({ nickname: "TestPlayer" })

        expect { consumer.consume }.not_to change { punishment&.reload&.active }
      end

      it "logs a warning about missing fields" do
        stub_messages({})

        expect(Rails.logger).to receive(:warn).with(/Пропущены обязательные поля/)
        consumer.consume
      end
    end

    context "with invalid issued_at" do
      it "skips when issued_at cannot be parsed" do
        minecraft_account
        punishment
        stub_messages({ nickname: "TestPlayer", issued_at: "not-a-date" })

        consumer.consume
        expect(punishment.reload.active).to be true
      end

      it "logs an error about unparseable issued_at" do
        minecraft_account
        stub_messages({ nickname: "TestPlayer", issued_at: "garbage" })

        expect(Rails.logger).to receive(:error).with(/Невозможно распарсить issued_at/)
        consumer.consume
      end
    end

    context "when MinecraftAccount is not found" do
      it "does not cancel any punishment" do
        punishment
        stub_messages({ nickname: "NonExistent", issued_at: issued_at.iso8601 })

        consumer.consume
        expect(punishment.reload.active).to be true
      end

      it "logs a warning about user not found" do
        stub_messages({ nickname: "Ghost", issued_at: issued_at.iso8601 })

        expect(Rails.logger).to receive(:warn).with(/не найден/)
        consumer.consume
      end
    end

    context "when punishment is not found" do
      it "does not raise an error" do
        minecraft_account
        stub_messages({ nickname: "TestPlayer", issued_at: issued_at.iso8601 })

        expect { consumer.consume }.not_to raise_error
      end

      it "logs a warning about punishment not found" do
        minecraft_account
        stub_messages({ nickname: "TestPlayer", issued_at: issued_at.iso8601 })

        expect(Rails.logger).to receive(:warn).with(/Наказание не найдено/)
        consumer.consume
      end
    end

    context "with multiple messages" do
      let(:reason2) { create(:punishment_reason, :mute) }
      let(:punishment2) do
        create(:users_punishment,
               user: user,
               bad_user: bad_user,
               punishment_reason: reason2,
               type: "mute",
               issued_at: 1.hour.ago,
               active: true)
      end

      before do
        minecraft_account
        punishment
        punishment2
      end

      it "processes all valid messages" do
        payloads = [
          { nickname: "TestPlayer", issued_at: issued_at.iso8601 },
          { nickname: "TestPlayer", issued_at: (issued_at - 1.hour).iso8601 }
        ]
        stub_messages(*payloads)
        consumer.consume

        expect(punishment.reload.active).to be false
        expect(punishment2.reload.active).to be false
      end
    end

    context "with invalid JSON string payload" do
      it "handles JSON parse errors gracefully" do
        stub_messages("not valid json{{{")

        expect { consumer.consume }.not_to raise_error
      end
    end
  end
end
