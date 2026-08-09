require "rails_helper"

RSpec.describe UserDataRequestConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    allow(UserDataProducer).to receive(:publish)
  end

  def build_message(payload)
    instance_double("Karafka::Messages::Message", payload: payload)
  end

  describe "#consume" do
    let!(:role) { create(:role, name: "User") }
    let!(:user) { create(:user, role: role) }

    context "when user exists" do
      let(:payload) { { "user_id" => user.id } }

      it "calls UserDataProducer.publish at least once with the user" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(UserDataProducer).to have_received(:publish).at_least(:once).with(user)
      end

      it "logs success message" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(Rails.logger).to have_received(:info).with(/Данные пользователя отправлены/)
      end
    end

    context "when user does not exist" do
      let(:payload) { { "user_id" => "nonexistent-id" } }

      it "logs a warning" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(Rails.logger).to have_received(:warn).with(/не найден/)
      end
    end

    context "with multiple messages" do
      let!(:user2) { create(:user, role: role) }
      let(:payloads) do
        [
          { "user_id" => user.id },
          { "user_id" => "nonexistent" },
          { "user_id" => user2.id }
        ]
      end

      it "processes each message" do
        messages = payloads.map { |p| build_message(p) }
        allow(consumer).to receive(:messages).and_return(messages)

        consumer.consume

        expect(UserDataProducer).to have_received(:publish).at_least(:once).with(user)
        expect(UserDataProducer).to have_received(:publish).at_least(:once).with(user2)
      end
    end

    context "when an error occurs" do
      let(:payload) { { "user_id" => user.id } }

      before do
        allow(User).to receive(:find_by).and_raise(StandardError.new("DB error"))
      end

      it "rescues and logs the error" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Ошибка в UserDataRequestConsumer/)
      end
    end

    context "when payload has string keys" do
      let(:payload) { { "user_id" => user.id } }

      it "correctly extracts user_id" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(UserDataProducer).to have_received(:publish).at_least(:once).with(user)
      end
    end
  end
end
