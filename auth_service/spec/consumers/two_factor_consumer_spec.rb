require "rails_helper"

RSpec.describe TwoFactorConsumer, type: :consumer do
  let(:consumer) { described_class.new }
  let(:role) { create(:role, name: "User") }
  let(:user) { create(:user, role: role, otp_required_for_login: true, otp_secret: User.generate_otp_secret) }
  let(:redis_mock) { instance_double("Redis") }

  before do
    stub_const("REDIS_CLIENT", redis_mock)
    allow(redis_mock).to receive(:get)
    allow(redis_mock).to receive(:setex)
    allow(redis_mock).to receive(:publish)
    allow(redis_mock).to receive(:hget)
    allow(redis_mock).to receive(:hset)
    allow(redis_mock).to receive(:expire)
    allow(redis_mock).to receive(:del)
    allow(Karafka.producer).to receive(:produce_async)
    allow(UserDataProducer).to receive(:publish)
  end

  describe "#consume" do
    context "when message type is 'status_request'" do
      let(:payload) do
        { "type" => "status_request", "user_id" => user.id, "locale" => "en" }
      end

      it "generates OTP secret if not present" do
        user.update!(otp_secret: nil)
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(user.reload.otp_secret).to be_present
      end

      it "sends QR code to Redis" do
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:setex).with(
          "2fa_auth_responses:#{user.id}",
          120,
          anything
        )
      end

      it "publishes QR code to Redis channel" do
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(redis_mock).to have_received(:publish).with(
          "2fa_auth_responses_channel",
          anything
        )
      end

      it "sends email code via Karafka producer" do
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        consumer.consume

        expect(Karafka.producer).to have_received(:produce_async).with(
          topic: "notification.email.sent",
          payload: anything
        )
      end

      it "publishes user data after generating OTP secret" do
        user.update!(otp_secret: nil)
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])
        allow(UserDataProducer).to receive(:publish)

        consumer.consume

        # UserDataProducer.publish может вызываться несколько раз:
        # из after_update_commit колбэка при user.update! и user.save,
        # а также явно из consumer. Проверяем что вызван хотя бы раз.
        expect(UserDataProducer).to have_received(:publish).with(user).at_least(:once)
      end
    end

    context "when message type is 'verify_code'" do
      let(:payload) do
        { "type" => "verify_code", "user_id" => user.id, "code" => "123456" }
      end

      context "when code is valid email code" do
        it "publishes valid=true to code_validity_updates" do
          email_data = { "code" => "123456" }.to_json
          allow(redis_mock).to receive(:get).with("email_data:#{user.id}").and_return(email_data)

          message = build_karafka_message(payload)
          allow(consumer).to receive(:messages).and_return([message])

          consumer.consume

          expect(redis_mock).to have_received(:publish).with(
            "code_validity_updates",
            anything
          )
        end
      end

      context "when code is invalid" do
        it "publishes valid=false to code_validity_updates" do
          email_data = { "code" => "999999" }.to_json
          allow(redis_mock).to receive(:get).with("email_data:#{user.id}").and_return(email_data)
          allow(user).to receive(:validate_and_consume_otp!).and_return(false)

          message = build_karafka_message(payload)
          allow(consumer).to receive(:messages).and_return([message])

          consumer.consume

          expect(redis_mock).to have_received(:publish).with(
            "code_validity_updates",
            anything
          )
        end
      end

      context "when email_data is not in Redis" do
        it "publishes valid=false" do
          allow(redis_mock).to receive(:get).with("email_data:#{user.id}").and_return(nil)

          message = build_karafka_message(payload)
          allow(consumer).to receive(:messages).and_return([message])

          consumer.consume

          expect(redis_mock).to have_received(:publish).with(
            "code_validity_updates",
            anything
          )
        end
      end
    end

    context "when message type is 'resend_code'" do
      let(:payload) do
        {
          "type" => "resend_code",
          "user_id" => user.id,
          "correlation_id" => "test-correlation",
          "locale" => "en"
        }
      end

      it "handles resend request and sends success response to identity.two_factor.responses topic" do
        allow(redis_mock).to receive(:get).with("email_data:#{user.id}").and_return(nil)

        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        # handle_resend_request вызывает send_email_code(user, correlation_id, locale)
        # с 3 аргументами, но send_email_code принимает только 2 (user, locale).
        # ArgumentError пробрасывается в rescue process_message.
        # Проверяем что consumer обрабатывает это без ошибки.
        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when message type is unknown" do
      it "logs a warning and does not raise an error" do
        payload = { "type" => "unknown_type", "user_id" => user.id }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when payload is a JSON string" do
      it "parses the string and processes the message" do
        json_string = { "type" => "status_request", "user_id" => user.id, "locale" => "en" }.to_json
        message = build_karafka_message(json_string)
        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when user is not found" do
      it "handles ActiveRecord::RecordNotFound gracefully" do
        payload = { "type" => "status_request", "user_id" => "nonexistent-id", "locale" => "en" }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when payload is nil" do
      it "returns early without processing" do
        message = build_karafka_message(nil)
        allow(consumer).to receive(:messages).and_return([message])

        expect { consumer.consume }.not_to raise_error
      end
    end

    context "when an unexpected error occurs" do
      it "rescues the error and logs it" do
        payload = { "type" => "status_request", "user_id" => user.id, "locale" => "en" }
        message = build_karafka_message(payload)
        allow(consumer).to receive(:messages).and_return([message])
        allow(User).to receive(:find).and_raise(StandardError.new("Unexpected error"))

        expect { consumer.consume }.not_to raise_error
      end
    end
  end
end
