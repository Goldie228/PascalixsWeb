require 'rails_helper'

RSpec.describe EmailConsumer do
  subject(:consumer) { described_class.new }

  let(:user_id) { 42 }
  let(:email) { 'user@example.com' }
  let(:code) { '123456' }
  let(:otp_valid_until) { '2026-07-21T12:00:00Z' }
  let(:locale) { 'en' }

  let(:payload) do
    {
      'user_id' => user_id,
      'email' => email,
      'code' => code,
      'otp_valid_until' => otp_valid_until,
      'locale' => locale
    }
  end

  # Karafka-сообщение с hash payload (EmailConsumer использует message.payload напрямую)
  let(:message) { instance_double(Karafka::Messages::Message, payload: payload) }

  before do
    allow(consumer).to receive(:messages).and_return([message])
    allow(UserMailer).to receive(:two_factor_code).and_return(
      instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    )
    allow(REDIS_CLIENT).to receive(:setex)
    allow(REDIS_CLIENT).to receive(:publish)
  end

  describe '#consume' do
    it 'calls UserMailer.two_factor_code with correct arguments' do
      consumer.consume

      expect(UserMailer).to have_received(:two_factor_code).with(email, code, otp_valid_until)
    end

    it 'delivers the email immediately' do
      mailer_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      allow(UserMailer).to receive(:two_factor_code).and_return(mailer_double)

      consumer.consume

      expect(mailer_double).to have_received(:deliver_now)
    end

    it 'stores OTP data in Redis with user-specific key and 120s TTL' do
      consumer.consume

      expect(REDIS_CLIENT).to have_received(:setex).with(
        "email_data:#{user_id}",
        120,
        { time: otp_valid_until, code: code }.to_json
      )
    end

    it 'publishes OTP data to Redis channel' do
      consumer.consume

      expect(REDIS_CLIENT).to have_received(:publish).with(
        'email_data_updates',
        { user_id: user_id, time: otp_valid_until, code: code }.to_json
      )
    end

    it 'sets I18n.locale from the payload' do
      consumer.consume

      expect(I18n.locale).to eq(:en)
    end

    context 'when message processing raises an error' do
      before do
        allow(UserMailer).to receive(:two_factor_code).and_raise(StandardError.new('SMTP error'))
      end

      it 'logs the error and does not raise' do
        expect { consumer.consume }.not_to raise_error
      end

      it 'does not call Redis when mailer fails' do
        consumer.consume

        expect(REDIS_CLIENT).not_to have_received(:setex)
        expect(REDIS_CLIENT).not_to have_received(:publish)
      end
    end

    context 'when payload has missing fields' do
      let(:payload) { { 'user_id' => user_id } }

      it 'still calls the mailer (with nil values) without raising' do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'with multiple messages' do
      let(:message2) { instance_double(Karafka::Messages::Message, payload: payload.merge('code' => '654321')) }

      before do
        allow(consumer).to receive(:messages).and_return([message, message2])
      end

      it 'processes each message' do
        consumer.consume

        expect(UserMailer).to have_received(:two_factor_code).twice
        expect(REDIS_CLIENT).to have_received(:setex).twice
      end
    end
  end
end
