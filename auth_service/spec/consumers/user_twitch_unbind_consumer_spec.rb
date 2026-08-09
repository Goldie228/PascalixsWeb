require "rails_helper"

RSpec.describe UserTwitchUnbindConsumer do
  # Подавляем побочные эффекты Redis и Kafka из колбэков модели
  before do
    allow(REDIS_CLIENT).to receive(:setex)
    allow(REDIS_CLIENT).to receive(:hset)
    allow(REDIS_CLIENT).to receive(:expire)
    allow(REDIS_CLIENT).to receive(:del)
    allow(UserDataProducer).to receive(:publish)
  end

  subject(:consumer) { described_class.new }

  # Мок Karafka-сообщения с вложенной структурой payload
  def build_message(user_id:, message_id: "msg-001")
    inner_payload = { "user_id" => user_id }
    outer_payload = { "payload" => inner_payload }

    double(
      "Karafka::Messages::Message",
      payload: outer_payload,
      id: message_id
    )
  end

  def build_message_with_json_string(user_id:, message_id: "msg-002")
    inner_payload = { "user_id" => user_id }.to_json
    outer_payload = { "payload" => inner_payload }

    double(
      "Karafka::Messages::Message",
      payload: outer_payload,
      id: message_id
    )
  end

  describe "#consume" do
    context "when user exists" do
      let!(:user) do
        create(:user).tap do |u|
          u.update_columns(
            twitch_channel_name: "MyTwitchChannel",
            twitch_url: "https://twitch.tv/mychannel"
          )
        end
      end

      it "clears twitch_channel_name and twitch_url" do
        message = build_message(user_id: user.id)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        user.reload
        expect(user.twitch_channel_name).to be_nil
        expect(user.twitch_url).to be_nil
      end

      it "handles payload that is a JSON string gracefully (does not clear fields)" do
        # Когда payload["payload"] — JSON-строка, .to_json кодирует повторно,
        # JSON.parse возвращает строку (не хэш), поэтому payload["user_id"] будет nil.
        # Consumer должен обработать это без ошибки.
        message = build_message_with_json_string(user_id: user.id)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        # Поля не меняются — user_id не найден (nil)
        user.reload
        expect(user.twitch_channel_name).to eq("MyTwitchChannel")
        expect(user.twitch_url).to eq("https://twitch.tv/mychannel")
      end

      it "processes multiple messages in a batch" do
        user2 = create(:user).tap do |u|
          u.update_columns(
            twitch_channel_name: "SecondChannel",
            twitch_url: "https://twitch.tv/second"
          )
        end

        messages = [
          build_message(user_id: user.id, message_id: "msg-a"),
          build_message(user_id: user2.id, message_id: "msg-b")
        ]
        allow(consumer).to receive(:messages).and_return(messages)

        consumer.consume

        expect(user.reload.twitch_channel_name).to be_nil
        expect(user2.reload.twitch_channel_name).to be_nil
      end
    end

    context "when user does not exist" do
      it "logs an error and continues without raising" do
        message = build_message(user_id: "nonexistent-uuid")
        allow(consumer).to receive(:messages).and_return([message])

        expect(Rails.logger).to receive(:error).with(/не найден/)

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when payload is malformed" do
      it "handles JSON::ParserError gracefully" do
        message = double(
          "Karafka::Messages::Message",
          payload: { "payload" => "not-valid-json{" },
          id: "msg-bad"
        )
        allow(consumer).to receive(:messages).and_return([message])

        # rescue nil на JSON.parse — payload будет nil,
        # затем payload["user_id"] вызовет NoMethodError, ловится общим rescue
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { consumer.consume }.not_to raise_error
      end

      it "handles unexpected errors gracefully" do
        message = double(
          "Karafka::Messages::Message",
          payload: nil,
          id: "msg-nil"
        )
        allow(consumer).to receive(:messages).and_return([message])

        expect(Rails.logger).to receive(:error).with(/Непредвиденная ошибка/)

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when user update fails" do
      it "rescues validation errors and logs them" do
        user = create(:user)
        message = build_message(user_id: user.id)
        allow(consumer).to receive(:messages).and_return([message])
        allow(User).to receive(:find_by).with(id: user.id).and_return(user)
        allow(user).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(user))

        expect(Rails.logger).to receive(:error).with(/Непредвиденная ошибка/)

        expect { consumer.consume }.not_to raise_error
      end
    end
  end
end
