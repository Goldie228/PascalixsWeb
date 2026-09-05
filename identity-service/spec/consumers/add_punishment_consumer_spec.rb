require "rails_helper"

RSpec.describe AddPunishmentConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  # Заглушки для внешних зависимостей
  before do
    allow(UserDataProducer).to receive(:publish)
    redis_client = double("REDIS_CLIENT")
    allow(redis_client).to receive(:hset)
    allow(redis_client).to receive(:expire)
    allow(redis_client).to receive(:del)
    stub_const("REDIS_CLIENT", redis_client)
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

  let(:user) { create(:user) }
  let(:bad_user) { create(:user) }
  let(:reason) { create(:punishment_reason, :ban, rule_number: 1) }
  let(:issued_at) { Time.current.iso8601 }

  let(:valid_payload) do
    {
      user_id: user.id,
      bad_user_id: bad_user.id,
      type: "ban",
      rule_number: reason.rule_number,
      issued_at: issued_at,
      duration: 86_400,
      expires_at: 1.day.from_now.iso8601,
      active: true
    }
  end

  describe "#consume" do
    context "with a valid payload" do
      it "creates a UsersPunishment record" do
        stub_messages(valid_payload)

        expect { consumer.consume }.to change(UsersPunishment, :count).by(1)
      end

      it "assigns correct attributes to the punishment" do
        stub_messages(valid_payload)
        consumer.consume

        punishment = UsersPunishment.last
        expect(punishment.user_id).to eq(user.id)
        expect(punishment.bad_user_id).to eq(bad_user.id)
        expect(punishment.type).to eq("ban")
        expect(punishment.punishment_reason).to eq(reason)
        expect(punishment.active).to be true
      end

      it "normalizes type to lowercase" do
        stub_messages(valid_payload.merge(type: "BAN"))
        consumer.consume

        expect(UsersPunishment.last.type).to eq("ban")
      end

      it "handles payload with string keys" do
        string_payload = valid_payload.stringify_keys
        stub_messages(string_payload)
        consumer.consume

        expect(UsersPunishment.count).to eq(1)
      end

      it "handles payload as JSON string" do
        json_payload = valid_payload.to_json
        stub_messages(json_payload)
        consumer.consume

        expect(UsersPunishment.count).to eq(1)
      end

      it "defaults active to true when not provided" do
        payload_without_active = valid_payload.except(:active)
        stub_messages(payload_without_active)
        consumer.consume

        expect(UsersPunishment.last.active).to be true
      end

      it "allows nil expires_at for permanent punishments" do
        payload = valid_payload.merge(expires_at: nil)
        stub_messages(payload)
        consumer.consume

        expect(UsersPunishment.last.expires_at).to be_nil
      end
    end

    context "with missing required keys" do
      it "skips message when user_id is missing" do
        stub_messages(valid_payload.except(:user_id))

        expect { consumer.consume }.not_to change(UsersPunishment, :count)
      end

      it "skips message when bad_user_id is missing" do
        stub_messages(valid_payload.except(:bad_user_id))

        expect { consumer.consume }.not_to change(UsersPunishment, :count)
      end

      it "skips message when type is missing" do
        stub_messages(valid_payload.except(:type))

        expect { consumer.consume }.not_to change(UsersPunishment, :count)
      end

      it "skips message when rule_number is missing" do
        stub_messages(valid_payload.except(:rule_number))

        expect { consumer.consume }.not_to change(UsersPunishment, :count)
      end

      it "skips message when issued_at is missing" do
        stub_messages(valid_payload.except(:issued_at))

        expect { consumer.consume }.not_to change(UsersPunishment, :count)
      end

      it "logs a warning about missing keys" do
        stub_messages(valid_payload.except(:user_id, :type))

        expect(Rails.logger).to receive(:warn).with(/Missing keys/)
        consumer.consume
      end
    end

    context "when PunishmentReason is not found" do
      it "does not create a punishment" do
        payload = valid_payload.merge(rule_number: 9999)
        stub_messages(payload)

        expect { consumer.consume }.not_to change(UsersPunishment, :count)
      end

      it "logs an error about reason not found" do
        payload = valid_payload.merge(rule_number: 9999)
        stub_messages(payload)

        expect(Rails.logger).to receive(:error).with(/Reason not found/)
        consumer.consume
      end
    end

    context "with multiple messages" do
      it "processes all valid messages" do
        reason2 = create(:punishment_reason, :mute, rule_number: 2)
        payload2 = valid_payload.merge(
          type: "mute",
          rule_number: reason2.rule_number,
          issued_at: 1.hour.ago.iso8601
        )

        stub_messages(valid_payload, payload2)

        expect { consumer.consume }.to change(UsersPunishment, :count).by(2)
      end

      it "continues processing after a failed message" do
        invalid_payload = valid_payload.except(:user_id)
        stub_messages(invalid_payload, valid_payload)

        expect { consumer.consume }.to change(UsersPunishment, :count).by(1)
      end
    end

    context "with invalid JSON string payload" do
      it "raises JSON::ParserError since parse is outside begin/rescue" do
        stub_messages("not valid json{{{")

        expect { consumer.consume }.to raise_error(JSON::ParserError)
      end
    end
  end
end
