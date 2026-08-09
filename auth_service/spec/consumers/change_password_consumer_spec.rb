require "rails_helper"

RSpec.describe ChangePasswordConsumer, type: :consumer do
  let(:consumer) { described_class.new }
  let(:role) { create(:role, name: "User") }
  let(:user) { create(:user, role: role) }
  let!(:minecraft_account) { create(:minecraft_account, user: user, nickname: "TestPlayer") }

  describe "#consume" do
    context "when message contains valid nickname and password" do
      it "updates the password_hash for the MinecraftAccount" do
        new_hashed_password = "$SHA$abc123$def456"
        payload = { "nickname" => minecraft_account.nickname, "password" => new_hashed_password }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(minecraft_account.reload.password_hash).to eq(new_hashed_password)
      end
    end

    context "when payload is a JSON string" do
      it "parses the string and updates the password" do
        new_hashed_password = "$SHA$salt$hash"
        json_string = { "nickname" => minecraft_account.nickname, "password" => new_hashed_password }.to_json
        message = build_karafka_message(json_string)

        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(minecraft_account.reload.password_hash).to eq(new_hashed_password)
      end
    end

    context "when nickname is missing from payload" do
      it "skips the message without updating any account" do
        original_hash = minecraft_account.password_hash
        payload = { "password" => "$SHA$salt$hash" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(minecraft_account.reload.password_hash).to eq(original_hash)
      end
    end

    context "when password is missing from payload" do
      it "skips the message without updating any account" do
        original_hash = minecraft_account.password_hash
        payload = { "nickname" => minecraft_account.nickname }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(minecraft_account.reload.password_hash).to eq(original_hash)
      end
    end

    context "when MinecraftAccount is not found for the nickname" do
      it "logs a warning and does not raise an error" do
        payload = { "nickname" => "NonExistentPlayer", "password" => "$SHA$salt$hash" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when payload contains invalid JSON" do
      it "rescues JSON::ParserError and logs the error" do
        message = build_karafka_message("not valid json {{{")

        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when account save fails" do
      it "logs the error and continues" do
        payload = { "nickname" => minecraft_account.nickname, "password" => "$SHA$salt$hash" }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])
        allow_any_instance_of(MinecraftAccount).to receive(:save).and_return(false)

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when processing multiple messages" do
      it "processes each message independently" do
        user1 = create(:user, role: role)
        user2 = create(:user, role: role)
        account1 = create(:minecraft_account, user: user1, nickname: "Player1")
        account2 = create(:minecraft_account, user: user2, nickname: "Player2")

        msg1 = build_karafka_message({ "nickname" => account1.nickname, "password" => "$SHA$hash1" })
        msg2 = build_karafka_message({ "nickname" => account2.nickname, "password" => "$SHA$hash2" })

        allow(consumer).to receive(:messages).and_return([msg1, msg2])

        consumer.consume

        expect(account1.reload.password_hash).to eq("$SHA$hash1")
        expect(account2.reload.password_hash).to eq("$SHA$hash2")
      end
    end

    context "when nickname has leading/trailing whitespace" do
      it "strips whitespace before lookup" do
        new_hashed_password = "$SHA$salt$hash"
        payload = { "nickname" => "  #{minecraft_account.nickname}  ", "password" => new_hashed_password }
        message = build_karafka_message(payload)

        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(minecraft_account.reload.password_hash).to eq(new_hashed_password)
      end
    end
  end
end
