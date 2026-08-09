require 'rails_helper'

RSpec.describe EmailUpdateJob, type: :job do
  let(:user_id) { "user_456" }
  let(:redis_client) { instance_double(Redis) }

  before do
    stub_const("REDIS_CLIENT", redis_client)
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when email data exists in Redis' do
      it 'broadcasts the email time to the user channel' do
        email_data = { time: "2026-07-22T11:00:00Z" }.to_json
        allow(redis_client).to receive(:get).with("email_data:#{user_id}").and_return(email_data)

        job.perform(user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "email:#{user_id}",
          { time: "2026-07-22T11:00:00Z" }
        )
      end
    end

    context 'when email data does not exist in Redis' do
      it 'does not broadcast anything' do
        allow(redis_client).to receive(:get).with("email_data:#{user_id}").and_return(nil)

        job.perform(user_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end

    context 'when email data is an empty string' do
      it 'does not broadcast' do
        allow(redis_client).to receive(:get).with("email_data:#{user_id}").and_return("")

        job.perform(user_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end
  end
end
