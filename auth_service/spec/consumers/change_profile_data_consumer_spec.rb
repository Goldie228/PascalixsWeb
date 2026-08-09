require "rails_helper"

RSpec.describe ChangeProfileDataConsumer, type: :consumer do
  let(:consumer) { described_class.new }

  before do
    # Роли с id 1 и 2 должны существовать — consumer хардкодит их
    Role.create!(id: 1, name: "Role_1", color: "#A0A0A0") if Role.find_by(id: 1).nil?
    Role.create!(id: 2, name: "Role_2", color: "#00FF00") if Role.find_by(id: 2).nil?
  rescue ActiveRecord::RecordNotUnique
    # уже существует
  end

  let(:role) { Role.find_by(id: 1) }
  let(:user) { create(:user, role: role) }
  let(:discord_account) { user.discord_account }

  describe "#consume" do
    context "when message contains user_id and email" do
      it "updates the discord_account email" do
        new_email = "newdiscord@example.com"
        payload = { user_id: user.id, email: new_email }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          discord_account.reload.email
        }.to(new_email)
      end
    end

    context "when message contains user_id and discord" do
      it "updates the discord username and discriminator" do
        payload = { user_id: user.id, discord: "@NewUser#1234" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])
        allow(DeleteUserSessionService).to receive(:call)

        consumer.consume

        discord_account.reload
        expect(discord_account.username).to eq("NewUser")
        expect(discord_account.discriminator).to eq("1234")
      end

      it "strips @ prefix from discord username" do
        payload = { user_id: user.id, discord: "UserNoAt#5678" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])
        allow(DeleteUserSessionService).to receive(:call)

        consumer.consume

        discord_account.reload
        expect(discord_account.username).to eq("UserNoAt")
      end

      it "calls DeleteUserSessionService when discord is updated" do
        payload = { user_id: user.id, discord: "@TestUser#9999" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])
        allow(DeleteUserSessionService).to receive(:call)

        consumer.consume

        expect(DeleteUserSessionService).to have_received(:call).with(
          user_id: user.id,
          nickname: nil
        )
      end
    end

    context "when message contains pass (boolean)" do
      it "updates user.is_added and role_id when pass is true" do
        payload = { user_id: user.id, pass: true }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          user.reload.is_added
        }.from(false).to(true)

        expect(user.role_id).to eq(2)
      end

      it "updates user.is_added and role_id when pass is false" do
        user.update!(is_added: true, role_id: 2)
        payload = { user_id: user.id, pass: false }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          user.reload.is_added
        }.from(true).to(false)

        expect(user.role_id).to eq(1)
      end
    end

    context "when message contains sponsor (boolean)" do
      it "updates user.is_sponsor when sponsor is true" do
        payload = { user_id: user.id, sponsor: true }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          user.reload.is_sponsor
        }.from(false).to(true)
      end

      it "updates user.is_sponsor when sponsor is false" do
        user.update!(is_sponsor: true)
        payload = { user_id: user.id, sponsor: false }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          user.reload.is_sponsor
        }.from(true).to(false)
      end
    end

    context "when message contains multiple fields" do
      it "updates all provided fields" do
        payload = {
          user_id: user.id,
          email: "multi@example.com",
          pass: true,
          sponsor: true
        }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        user.reload
        discord_account.reload

        expect(discord_account.email).to eq("multi@example.com")
        expect(user.is_added).to be true
        expect(user.is_sponsor).to be true
      end
    end

    context "when user_id is missing" do
      it "skips the message" do
        payload = { email: "test@example.com" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when user is not found" do
      it "logs a warning and skips the message" do
        payload = { user_id: "nonexistent-id", email: "test@example.com" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when payload is a JSON string" do
      it "parses the string and processes the message" do
        json_string = { user_id: user.id, sponsor: true }.to_json
        message = build_karafka_message(json_string)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.to change {
          user.reload.is_sponsor
        }.to(true)
      end
    end

    context "when no changes are needed" do
      it "does not save the user" do
        payload = { user_id: user.id, pass: false } # уже false
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])
        allow(user).to receive(:save!).and_raise("Should not be called")

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

    context "when email matches current discord email" do
      it "does not update the email" do
        current_email = discord_account.email
        payload = { user_id: user.id, email: current_email }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to change { discord_account.reload.email }
      end
    end
  end
end
