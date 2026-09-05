require "rails_helper"

# Заглушка для AuthEventsProducer если класса нет
unless defined?(AuthEventsProducer)
  class AuthEventsProducer
    def self.user_registered(*args); end
    def self.user_logged_in(*args); end
    def self.user_logged_out(*args); end
    def self.authentication_successful(*args); end
    def self.authentication_failed(*args); end
  end
end

RSpec.describe UserRegistrationConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  # Заглушка внешних продюсеров
  before do
    allow(AuthEventsProducer).to receive(:user_registered)
    allow(UserDataProducer).to receive(:publish)
  end

  def build_message(payload)
    instance_double("Karafka::Messages::Message", payload: payload)
  end

  describe "#consume" do
    context "with a valid registration payload" do
      let(:payload) do
        {
          "user_id" => "abc-123",
          "email" => "test@example.com",
          "nickname" => "TestPlayer"
        }.to_json
      end

      it "processes the message without errors" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
      end

      it "outputs the registration event" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.to output(/Received registration event/).to_stdout
      end
    end

    context "with multiple messages" do
      let(:payloads) do
        [
          { "user_id" => "user-1", "email" => "one@example.com" }.to_json,
          { "user_id" => "user-2", "email" => "two@example.com" }.to_json
        ]
      end

      it "processes all messages" do
        messages = payloads.map { |p| build_message(p) }
        allow(consumer).to receive(:messages).and_return(messages)

        expect { consumer.consume }.to output(/Received registration event/).to_stdout
      end
    end

    context "with invalid JSON payload" do
      let(:payload) { "not valid json{" }

      it "raises JSON::ParserError" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.to raise_error(JSON::ParserError)
      end
    end

    context "with empty payload" do
      let(:payload) { {}.to_json }

      it "processes without errors" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
      end
    end
  end
end
