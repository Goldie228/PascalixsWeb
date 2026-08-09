require "rails_helper"

RSpec.describe SetAboutMeConsumer, type: :consumer do
  let(:consumer) { described_class.new }
  let(:role) { create(:role, name: "User") }
  let(:user) { create(:user, role: role) }

  describe "#consume" do
    context "when message contains valid user_id and about_me" do
      it "updates the user's about_me field" do
        new_about_me = "This is my new bio"
        # SetAboutMeConsumer ожидает payload в ключе "payload"
        raw_payload = { "payload" => { "user_id" => user.id, "about_me" => new_about_me } }
        message = build_karafka_message(raw_payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          user.reload.about_me
        }.from(user.about_me).to(new_about_me)
      end
    end

    context "when about_me is an empty string" do
      it "clears the user's about_me field" do
        user.update!(about_me: "Old bio")
        raw_payload = { "payload" => { "user_id" => user.id, "about_me" => "" } }
        message = build_karafka_message(raw_payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          user.reload.about_me
        }.from("Old bio").to("")
      end
    end

    context "when user is not found" do
      it "logs an error and skips the message" do
        raw_payload = { "payload" => { "user_id" => "nonexistent-id", "about_me" => "Bio" } }
        message = build_karafka_message(raw_payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when payload is nil or malformed" do
      it "rescues the error and continues" do
        message = build_karafka_message({ "payload" => nil })

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when payload JSON parsing fails" do
      it "rescues JSON::ParserError and logs the error" do
        # Сообщение где payload["payload"].to_json завершится ошибкой
        raw_payload = { "payload" => "not valid json" }
        message = build_karafka_message(raw_payload)

        allow(consumer).to receive(:messages).and_return([message])

        # Consumer использует JSON.parse с rescue nil
        # и должен обработать это без ошибки
        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when processing multiple messages" do
      it "processes each message independently" do
        user1 = create(:user, role: role, about_me: "Bio 1")
        user2 = create(:user, role: role, about_me: "Bio 2")

        msg1 = build_karafka_message({ "payload" => { "user_id" => user1.id, "about_me" => "Updated 1" } })
        msg2 = build_karafka_message({ "payload" => { "user_id" => user2.id, "about_me" => "Updated 2" } })

        allow(consumer).to receive(:messages).and_return([msg1, msg2])

        consumer.consume

        expect(user1.reload.about_me).to eq("Updated 1")
        expect(user2.reload.about_me).to eq("Updated 2")
      end
    end

    context "when about_me exceeds maximum length" do
      it "handles validation error gracefully" do
        long_bio = "a" * 300 # превышает лимит 250 символов
        raw_payload = { "payload" => { "user_id" => user.id, "about_me" => long_bio } }
        message = build_karafka_message(raw_payload)

        allow(consumer).to receive(:messages).and_return([message])

        # Consumer вызывает user.update — может провалить валидацию
        # но не должен выбрасывать ошибку
        expect { consumer.consume }.not_to raise_error
      end
    end
  end
end
