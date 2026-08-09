require 'rails_helper'

RSpec.describe TwoFactorUpdateJob, type: :job do
  let(:user_id) { "user_2fa_update_456" }
  let(:redis_client) { instance_double(Redis) }

  before do
    stub_const("REDIS_CLIENT", redis_client)
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when 2FA response exists in Redis' do
      it 'broadcasts the QR code URL with XML declaration stripped' do
        qr_url = "<?xml version=\"1.0\"?>otpauth://totp/Example:user@test.com?secret=ABCDEFG"
        response_data = { qr_code_url: qr_url }.to_json
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}").and_return(response_data)

        job.perform(user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "two_factor_auth:#{user_id}",
          { qr_code_url: "otpauth://totp/Example:user@test.com?secret=ABCDEFG" }
        )
      end

      it 'handles QR code URL without XML declaration' do
        qr_url = "otpauth://totp/Test:user@example.com?secret=XYZ123"
        response_data = { qr_code_url: qr_url }.to_json
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}").and_return(response_data)

        job.perform(user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "two_factor_auth:#{user_id}",
          { qr_code_url: "otpauth://totp/Test:user@example.com?secret=XYZ123" }
        )
      end
    end

    context 'when 2FA response does not exist in Redis' do
      it 'does not broadcast anything' do
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}").and_return(nil)

        job.perform(user_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end

    context 'when 2FA response is an empty string' do
      it 'does not broadcast' do
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}").and_return("")

        job.perform(user_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end

    context 'when Redis returns malformed JSON' do
      it 'raises a JSON parse error' do
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}").and_return("not json")

        expect { job.perform(user_id) }.to raise_error(JSON::ParserError)
      end
    end
  end
end
