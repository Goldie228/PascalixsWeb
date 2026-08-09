require "rails_helper"

RSpec.describe ChangeEmailConsumer, type: :consumer do
  let(:consumer) { described_class.new }
  let(:role) { create(:role, name: "User") }
  let(:user) { create(:user, role: role) }
  let(:discord_account) { user.discord_account }

  describe "#consume" do
    context "when message contains valid user_id and email" do
      it "updates the user's email via discord_account" do
        new_email = "newemail@example.com"
        payload = { user_id: user.id, email: new_email }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          discord_account.reload.email
        }.from(discord_account.email).to(new_email)
      end
    end

    context "when payload is a JSON string" do
      it "parses the string and updates the email" do
        new_email = "parsed@example.com"
        json_string = { user_id: user.id, email: new_email }.to_json
        message = build_karafka_message(json_string)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          discord_account.reload.email
        }.to(new_email)
      end
    end

    context "when user is not found" do
      it "logs an error and skips the message" do
        payload = { user_id: "nonexistent-id", email: "test@example.com" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when discord_account is not found for the user" do
      it "logs an error and skips the message" do
        user_without_discord = create(:user, role: role)
        # Удаляем discord_account если создан
        user_without_discord.discord_account&.destroy

        payload = { user_id: user_without_discord.id, email: "test@example.com" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when payload contains invalid JSON" do
      it "rescues JSON::ParserError and logs the error" do
        message = build_karafka_message("invalid json {{{")

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when user save fails" do
      it "logs the error and continues" do
        payload = { user_id: user.id, email: "invalid-email" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        # Метод email= делегирует в discord_account
        # Если сохранение discord_account проваливается — логируем ошибку
        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when processing multiple messages" do
      it "processes each message independently" do
        user1 = create(:user, role: role)
        user2 = create(:user, role: role)

        msg1 = build_karafka_message({ user_id: user1.id, email: "user1@example.com" })
        msg2 = build_karafka_message({ user_id: user2.id, email: "user2@example.com" })

        allow(consumer).to receive(:messages).and_return([msg1, msg2])

        consumer.consume

        expect(user1.discord_account.reload.email).to eq("user1@example.com")
        expect(user2.discord_account.reload.email).to eq("user2@example.com")
      end
    end
  end
end
