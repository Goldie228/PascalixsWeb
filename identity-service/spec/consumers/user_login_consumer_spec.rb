require "rails_helper"

RSpec.describe UserLoginConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  let(:redis_mock) { instance_double("Redis") }

  before do
    stub_const("REDIS_CLIENT", redis_mock)
    allow(redis_mock).to receive(:publish)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    allow(UserDataProducer).to receive(:publish)
    # Не даём after_commit колбэкам вызвать UserDataProducer
    allow(AuthEventsProducer).to receive_messages(
      user_registered: nil,
      user_logged_in: nil,
      user_logged_out: nil,
      authentication_successful: nil,
      authentication_failed: nil
    ) unless defined?(AuthEventsProducer)
  end

  def build_message(payload)
    instance_double("Karafka::Messages::Message", payload: payload)
  end

  describe "#consume" do
    let(:correlation_id) { "corr-123" }
    let(:role) { create(:role, name: "User") }
    let(:user) { create(:user, role: role) }
    let(:minecraft_account) do
      create(:minecraft_account, user: user, nickname: "TestPlayer_#{SecureRandom.hex(4)}")
    end

    context "when account exists and password is correct" do
      let(:payload) do
        {
          "correlation_id" => correlation_id,
          "nickname" => minecraft_account.nickname,
          "password" => "Password1"
        }.to_json
      end

      it "publishes success response to Redis" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(redis_mock).to have_received(:publish).with(
          "auth_responses:#{correlation_id}",
          a_string_including('"status":"auth"')
        )
      end

      it "includes user_id in success response" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(redis_mock).to have_received(:publish).with(
          "auth_responses:#{correlation_id}",
          a_string_including(user.id)
        )
      end
    end

    context "when account exists but password is wrong" do
      let(:payload) do
        {
          "correlation_id" => correlation_id,
          "nickname" => minecraft_account.nickname,
          "password" => "WrongPassword1"
        }.to_json
      end

      it "publishes failure response" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(redis_mock).to have_received(:publish).with(
          "auth_responses:#{correlation_id}",
          a_string_including('"status":"not auth"')
        )
      end
    end

    context "when account is not found" do
      let(:payload) do
        {
          "correlation_id" => correlation_id,
          "nickname" => "NonExistentPlayer",
          "password" => "Password1"
        }.to_json
      end

      it "publishes failure response" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(redis_mock).to have_received(:publish).with(
          "auth_responses:#{correlation_id}",
          a_string_including('"status":"not auth"')
        )
      end
    end

    context "when an unexpected error occurs" do
      let(:payload) do
        {
          "correlation_id" => correlation_id,
          "nickname" => "TestPlayer",
          "password" => "Password1"
        }.to_json
      end

      it "rescues the error and publishes failure" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])
        allow(MinecraftAccount).to receive(:find_by).and_raise(StandardError.new("DB error"))

        consumer.consume

        expect(redis_mock).to have_received(:publish).with(
          "auth_responses:#{correlation_id}",
          a_string_including('"status":"not auth"')
        )
      end

      it "logs the error" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])
        allow(MinecraftAccount).to receive(:find_by).and_raise(StandardError.new("DB error"))

        consumer.consume

        expect(Rails.logger).to have_received(:error).with(/Login processing failed/)
      end
    end

    context "with multiple messages" do
      let(:payloads) do
        [
          { "correlation_id" => "corr-1", "nickname" => "NoOne", "password" => "x" }.to_json,
          { "correlation_id" => "corr-2", "nickname" => minecraft_account.nickname, "password" => "Password1" }.to_json
        ]
      end

      it "processes each message independently" do
        messages = payloads.map { |p| build_message(p) }
        allow(consumer).to receive(:messages).and_return(messages)

        consumer.consume

        expect(redis_mock).to have_received(:publish).with(
          "auth_responses:corr-1",
          a_string_including('"status":"not auth"')
        )
        expect(redis_mock).to have_received(:publish).with(
          "auth_responses:corr-2",
          a_string_including('"status":"auth"')
        )
      end
    end
  end
end
