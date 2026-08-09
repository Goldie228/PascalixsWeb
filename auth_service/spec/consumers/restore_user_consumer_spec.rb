require "rails_helper"

RSpec.describe RestoreUserConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  def build_message(payload)
    instance_double("Karafka::Messages::Message", payload: payload)
  end

  describe "#consume" do
    context "when nickname exists in droped_users" do
      let!(:droped_user) { create(:droped_user, name: "RestorablePlayer") }
      let(:payload) { { nickname: "RestorablePlayer" }.to_json }

      it "removes the player from droped_users" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(DropedUser.exists?(name: "RestorablePlayer")).to be false
      end

      it "logs restoration" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(Rails.logger).to have_received(:info).with(/восстановлен/)
      end
    end

    context "when nickname is NOT in droped_users" do
      let(:payload) { { nickname: "NeverDeleted" }.to_json }

      it "logs a warning" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(Rails.logger).to have_received(:warn).with(/не найден среди удалённых/)
      end

      it "does not raise an error" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when required fields are missing" do
      let(:payload) { { email: "test@example.com" }.to_json }

      it "skips the message and logs warning" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(Rails.logger).to have_received(:warn).with(/Пропущены обязательные поля/)
      end
    end

    context "when nickname is blank" do
      let(:payload) { { nickname: "   " }.to_json }

      it "skips processing" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(DropedUser.count).to eq(0)
      end
    end

    context "with hash payload (not JSON string)" do
      let!(:droped_user) { create(:droped_user, name: "HashPlayer") }
      let(:payload) { { nickname: "HashPlayer" } }

      it "handles symbolized hash payload" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(DropedUser.exists?(name: "HashPlayer")).to be false
      end
    end

    context "with invalid JSON" do
      let(:payload) { "not valid json{" }

      it "rescues JSON::ParserError" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Ошибка парсинга JSON/)
      end
    end

    context "with multiple messages" do
      let!(:dp1) { create(:droped_user, name: "Player_One") }
      let!(:dp2) { create(:droped_user, name: "Player_Two") }
      let(:payloads) do
        [
          { nickname: "Player_One" }.to_json,
          { nickname: "Player_Two" }.to_json
        ]
      end

      it "processes all messages" do
        messages = payloads.map { |p| build_message(p) }
        allow(consumer).to receive(:messages).and_return(messages)

        consumer.consume

        expect(DropedUser.exists?(name: "Player_One")).to be false
        expect(DropedUser.exists?(name: "Player_Two")).to be false
      end
    end

    context "when an unexpected error occurs" do
      let(:payload) { { nickname: "TestPlayer" }.to_json }

      before do
        allow(DropedUser).to receive(:exists?).and_raise(StandardError.new("DB error"))
      end

      it "rescues and logs the error" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Необработанная ошибка/)
      end
    end
  end
end
