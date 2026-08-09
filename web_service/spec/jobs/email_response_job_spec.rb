require 'rails_helper'

RSpec.describe EmailResponseJob, type: :job do
  let(:user_id) { "user_123" }
  let(:redis_instance) { instance_double(Redis) }

  before do
    allow(Redis).to receive(:new).and_return(redis_instance)
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when email data is available immediately' do
      it 'broadcasts the email time to the user channel' do
        email_data = { time: "2026-07-22T10:00:00Z" }.to_json
        allow(redis_instance).to receive(:get).with("email_data:#{user_id}").and_return(email_data)

        job.perform(user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "email:#{user_id}",
          { time: "2026-07-22T10:00:00Z" }
        )
      end
    end

    context 'when email data is not available initially' do
      it 'polls until data is available and then broadcasts' do
        email_data = { time: "2026-07-22T10:00:00Z" }.to_json

        # nil для первых 2 попыток, затем данные
        call_count = 0
        allow(redis_instance).to receive(:get).with("email_data:#{user_id}") do
          call_count += 1
          call_count >= 3 ? email_data : nil
        end

        # Ускоряем тест через заглушку sleep
        allow(job).to receive(:sleep)

        job.perform(user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "email:#{user_id}",
          { time: "2026-07-22T10:00:00Z" }
        )
      end
    end

    context 'when email data is never available' do
      it 'stops polling after 30 attempts without broadcasting' do
        allow(redis_instance).to receive(:get).with("email_data:#{user_id}").and_return(nil)
        allow(job).to receive(:sleep)

        job.perform(user_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end
  end
end
