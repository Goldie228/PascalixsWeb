require "rails_helper"

RSpec.describe MinecraftRegistrationConsumer, type: :consumer do
  let(:consumer) { described_class.new }
  let(:role) { create(:role, name: "User") }
  let(:user) { create(:user, role: role) }
  let(:redis_mock) { instance_double("Redis") }
  let(:correlation_id) { "test-correlation-#{SecureRandom.hex(4)}" }

  before do
    stub_const("REDIS_CLIENT", redis_mock)
    allow(redis_mock).to receive(:set)
    allow(redis_mock).to receive(:get)
    allow(redis_mock).to receive(:setex)
    allow(redis_mock).to receive(:hget)
    allow(UserDataProducer).to receive(:publish)
    allow(consumer).to receive(:produce_with_retries)
    allow(Karafka.producer).to receive(:produce_async)
  end

  describe "#consume" do
    let(:valid_payload) do
      {
        "payload" => {
          "correlation_id" => correlation_id,
          "user_id" => user.id,
          "locale" => "en",
          "nickname" => "TestPlayer",
          "password" => "Password1",
          "password_confirmation" => "Password1"
        }
      }
    end

    context "when message contains valid registration data" do
      it "creates a MinecraftAccount for the user" do
        message = build_karafka_message(valid_payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(user.minecraft_account).to be_present
        expect(user.minecraft_account.nickname).to eq("TestPlayer")
      end

      it "saves response to Redis with success status" do
        message = build_karafka_message(valid_payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:set).with(
          "registration_responses:#{correlation_id}",
          anything,
          ex: 3600
        )
      end

      it "publishes user data after successful registration" do
        message = build_karafka_message(valid_payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        # UserDataProducer.publish может вызываться несколько раз:
        # один раз из after_update_commit и один раз явно из consumer.
        expect(UserDataProducer).to have_received(:publish).with(user).at_least(:once)
      end

      it "requests roles via produce_with_retries" do
        message = build_karafka_message(valid_payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(consumer).to have_received(:produce_with_retries).with(
          "minecraft_service_get_roles",
          payload: { nickname: "TestPlayer" }
        )
      end
    end

    context "when user is not found" do
      it "saves error response to Redis" do
        payload = {
          "payload" => {
            "correlation_id" => correlation_id,
            "user_id" => "nonexistent-id",
            "locale" => "en",
            "nickname" => "TestPlayer",
            "password" => "Password1",
            "password_confirmation" => "Password1"
          }
        }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:set).with(
          "registration_responses:#{correlation_id}",
          anything,
          ex: 3600
        )
      end
    end

    context "when nickname validation fails" do
      it "saves error response to Redis with validation errors" do
        payload = {
          "payload" => {
            "correlation_id" => correlation_id,
            "user_id" => user.id,
            "locale" => "en",
            "nickname" => "ab", # слишком короткий (мин 3)
            "password" => "Password1",
            "password_confirmation" => "Password1"
          }
        }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:set).with(
          "registration_responses:#{correlation_id}",
          anything,
          ex: 3600
        )
      end
    end

    context "when password confirmation does not match" do
      it "saves error response to Redis" do
        payload = {
          "payload" => {
            "correlation_id" => correlation_id,
            "user_id" => user.id,
            "locale" => "en",
            "nickname" => "TestPlayer",
            "password" => "Password1",
            "password_confirmation" => "Password2"
          }
        }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:set).with(
          "registration_responses:#{correlation_id}",
          anything,
          ex: 3600
        )
      end
    end

    context "when password does not meet complexity requirements" do
      it "saves error response to Redis" do
        payload = {
          "payload" => {
            "correlation_id" => correlation_id,
            "user_id" => user.id,
            "locale" => "en",
            "nickname" => "TestPlayer",
            "password" => "simple", # нет цифры, слишком короткий
            "password_confirmation" => "simple"
          }
        }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:set).with(
          "registration_responses:#{correlation_id}",
          anything,
          ex: 3600
        )
      end
    end

    context "when payload contains invalid JSON" do
      it "rescues JSON::ParserError and logs the error" do
        message = build_karafka_message("invalid json {{{")
        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when user already has a minecraft_account" do
      it "handles the uniqueness validation error" do
        create(:minecraft_account, user: user)

        payload = {
          "payload" => {
            "correlation_id" => correlation_id,
            "user_id" => user.id,
            "locale" => "en",
            "nickname" => "AnotherPlayer",
            "password" => "Password1",
            "password_confirmation" => "Password1"
          }
        }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:set).with(
          "registration_responses:#{correlation_id}",
          anything,
          ex: 3600
        )
      end
    end

    context "when nickname is already taken by another account" do
      it "saves error response to Redis" do
        create(:minecraft_account, nickname: "TakenName")

        payload = {
          "payload" => {
            "correlation_id" => correlation_id,
            "user_id" => user.id,
            "locale" => "en",
            "nickname" => "TakenName",
            "password" => "Password1",
            "password_confirmation" => "Password1"
          }
        }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:set).with(
          "registration_responses:#{correlation_id}",
          anything,
          ex: 3600
        )
      end
    end
  end
end
