require 'rails_helper'

RSpec.describe TwoFactorResponseJob, type: :job do
  let(:user_id) { "user_2fa_123" }
  let(:redis_client) { instance_double(Redis) }

  before do
    stub_const("REDIS_CLIENT", redis_client)
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when 2FA response is available immediately' do
      it 'broadcasts the QR code URL with XML declaration stripped' do
        qr_url = "<?xml version=\"1.0\"?>otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP"
        response_data = { qr_code_url: qr_url }.to_json
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}").and_return(response_data)

        job.perform(user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "two_factor_auth:#{user_id}",
          { qr_code_url: "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP" }
        )
      end
    end

    context 'when 2FA response is not available initially' do
      it 'polls until data is available' do
        qr_url = "otpauth://totp/Test"
        response_data = { qr_code_url: qr_url }.to_json

        call_count = 0
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}") do
          call_count += 1
          call_count >= 3 ? response_data : nil
        end

        allow(job).to receive(:sleep)

        job.perform(user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "two_factor_auth:#{user_id}",
          { qr_code_url: "otpauth://totp/Test" }
        )
      end
    end

    context 'when 2FA response is never available' do
      it 'stops polling after 30 attempts without broadcasting' do
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}").and_return(nil)
        allow(job).to receive(:sleep)

        job.perform(user_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end

    context 'when QR code URL contains XML declaration' do
      it 'strips the XML declaration' do
        qr_url = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>otpauth://totp/Test"
        response_data = { qr_code_url: qr_url }.to_json
        allow(redis_client).to receive(:get).with("2fa_auth_responses:#{user_id}").and_return(response_data)

        job.perform(user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "two_factor_auth:#{user_id}",
          { qr_code_url: "otpauth://totp/Test" }
        )
      end
    end
  end
end
