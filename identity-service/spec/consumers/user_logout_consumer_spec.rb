require "rails_helper"

RSpec.describe UserLogoutConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  # Моки классов с методами ActiveRecord
  let(:session_class) do
    Class.new do
      def self.find_by(**args); end
    end
  end

  let(:audit_log_class) do
    Class.new do
      def self.create(**args); end
    end
  end

  before do
    stub_const("Session", session_class)
    stub_const("AuditLog", audit_log_class)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  def build_message(payload)
    instance_double("Karafka::Messages::Message", payload: payload)
  end

  describe "#consume" do
    let(:user) { create(:user) }
    let(:token) { "session-token-abc" }
    let(:ip_address) { "192.168.1.1" }
    let(:timestamp) { Time.current.to_i }
    let(:session) { instance_double("Session", user: user) }

    context "with valid token and existing session" do
      let(:payload) do
        { "token" => token, "ip_address" => ip_address, "timestamp" => timestamp }.to_json
      end

      before do
        allow(Session).to receive(:find_by).with(token: token).and_return(session)
        allow(user).to receive(:update)
        allow(AuditLog).to receive(:create)
      end

      it "updates user last_logout_at" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(user).to have_received(:update).with(last_logout_at: Time.at(timestamp))
      end

      it "creates an audit log entry" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(AuditLog).to have_received(:create).with(
          user_id: user.id,
          action: "logout",
          ip_address: ip_address,
          created_at: Time.at(timestamp)
        )
      end
    end

    context "when session is not found" do
      let(:payload) do
        { "token" => "unknown-token", "ip_address" => ip_address, "timestamp" => timestamp }.to_json
      end

      before do
        allow(Session).to receive(:find_by).with(token: "unknown-token").and_return(nil)
        allow(AuditLog).to receive(:create)
      end

      it "logs a warning" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(Rails.logger).to have_received(:warn).with(/No session found for token/)
      end

      it "does not create an audit log" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(AuditLog).not_to have_received(:create)
      end
    end

    context "when token is missing" do
      let(:payload) do
        { "ip_address" => ip_address, "timestamp" => timestamp }.to_json
      end

      it "logs a warning about missing token" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        consumer.consume

        expect(Rails.logger).to have_received(:warn).with(/without token/)
      end
    end

    context "when an error occurs during processing" do
      let(:payload) do
        { "token" => token, "ip_address" => ip_address, "timestamp" => timestamp }.to_json
      end

      before do
        allow(Session).to receive(:find_by).and_raise(StandardError.new("DB error"))
      end

      it "rescues the error and logs it" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Error processing logout event/)
      end
    end

    context "with invalid JSON" do
      let(:payload) { "not json{" }

      it "rescues JSON parse error" do
        allow(consumer).to receive(:messages).and_return([build_message(payload)])

        expect { consumer.consume }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/Error processing logout event/)
      end
    end
  end
end
