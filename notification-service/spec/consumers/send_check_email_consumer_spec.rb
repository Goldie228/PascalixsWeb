require 'rails_helper'

RSpec.describe SendCheckEmailConsumer do
  subject(:consumer) { described_class.new }

  let(:email) { 'user@example.com' }
  let(:token) { 'abc123token' }
  let(:nickname) { 'TestUser' }
  let(:locale) { 'en' }
  let(:time_zone) { 'America/New_York' }

  let(:raw_payload) do
    {
      'email' => email,
      'token' => token,
      'nickname' => nickname,
      'locale' => locale,
      'time_zone' => time_zone
    }
  end

  # SendCheckEmailConsumer вызывает JSON.parse(message.payload) — payload JSON-строка
  let(:message) { instance_double(Karafka::Messages::Message, payload: raw_payload.to_json) }

  before do
    allow(consumer).to receive(:messages).and_return([message])
    allow(UserMailer).to receive(:check_email).and_return(
      instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    )
  end

  describe '#consume' do
    it 'calls UserMailer.check_email with correct arguments' do
      consumer.consume

      expect(UserMailer).to have_received(:check_email).with(email, token, nickname, time_zone)
    end

    it 'delivers the email immediately' do
      mailer_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      allow(UserMailer).to receive(:check_email).and_return(mailer_double)

      consumer.consume

      expect(mailer_double).to have_received(:deliver_now)
    end

    it 'sets I18n.locale from the payload when locale is available' do
      consumer.consume

      expect(I18n.locale).to eq(:en)
    end

    context 'when locale is not in available_locales' do
      let(:locale) { 'xx' }

      it 'falls back to I18n.default_locale' do
        consumer.consume

        expect(I18n.locale).to eq(I18n.default_locale)
      end
    end

    context 'when time_zone is invalid' do
      let(:time_zone) { 'Invalid/Zone' }

      it 'falls back to UTC' do
        consumer.consume

        expect(UserMailer).to have_received(:check_email).with(email, token, nickname, 'UTC')
      end
    end

    context 'when time_zone is empty' do
      let(:time_zone) { '' }

      it 'falls back to UTC' do
        consumer.consume

        expect(UserMailer).to have_received(:check_email).with(email, token, nickname, 'UTC')
      end
    end

    context 'when message processing raises an error' do
      before do
        allow(UserMailer).to receive(:check_email).and_raise(StandardError.new('delivery failed'))
      end

      it 'logs the error and does not raise' do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when payload is invalid JSON' do
      let(:message) { instance_double(Karafka::Messages::Message, payload: 'not valid json{{{') }

      it 'rescues the error and does not raise' do
        expect { consumer.consume }.not_to raise_error
      end

      it 'does not call the mailer' do
        consumer.consume

        expect(UserMailer).not_to have_received(:check_email)
      end
    end

    context 'when payload has missing fields' do
      let(:raw_payload) { { 'email' => email } }

      it 'calls the mailer with nil values without raising' do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'with multiple messages' do
      let(:message2) do
        instance_double(
          Karafka::Messages::Message,
          payload: raw_payload.merge('token' => 'other_token').to_json
        )
      end

      before do
        allow(consumer).to receive(:messages).and_return([message, message2])
      end

      it 'processes each message' do
        consumer.consume

        expect(UserMailer).to have_received(:check_email).twice
      end
    end
  end
end
