require 'rails_helper'

RSpec.describe RegistrationResponseJob, type: :job do
  let(:correlation_id) { "reg_corr_123" }
  let(:user_id) { "user_reg_456" }
  let(:redis_client) { instance_double(Redis) }

  before do
    stub_const("REDIS_CLIENT", redis_client)
    allow(ActionCable.server).to receive(:broadcast)
    allow(Rails.logger).to receive(:info)
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when a response is received within timeout' do
      it 'broadcasts the response with camelCase keys' do
        response_data = { status: "success", user_name: "john" }.to_json
        allow(redis_client).to receive(:get).with("registration_responses:#{correlation_id}").and_return(response_data)
        allow(redis_client).to receive(:del)

        job.perform(correlation_id, user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "registration_channel_#{user_id}",
          { response: { "status" => "success", "userName" => "john" } }
        )
      end

      it 'cleans up the Redis key after processing' do
        response_data = { status: "success" }.to_json
        allow(redis_client).to receive(:get).with("registration_responses:#{correlation_id}").and_return(response_data)
        expect(redis_client).to receive(:del).with("registration_responses:#{correlation_id}")

        job.perform(correlation_id, user_id)
      end
    end

    context 'when no response is received within timeout' do
      it 'does not broadcast and cleans up Redis' do
        allow(redis_client).to receive(:get).with("registration_responses:#{correlation_id}").and_return(nil)
        allow(redis_client).to receive(:del)

        # Ускоряем тест
        allow(job).to receive(:sleep)

        job.perform(correlation_id, user_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
        expect(redis_client).to have_received(:del).with("registration_responses:#{correlation_id}")
      end
    end

    context 'when response becomes available after polling' do
      it 'broadcasts once data is available' do
        response_data = { status: "success", email: "test@example.com" }.to_json

        call_count = 0
        allow(redis_client).to receive(:get).with("registration_responses:#{correlation_id}") do
          call_count += 1
          call_count >= 2 ? response_data : nil
        end
        allow(redis_client).to receive(:del)
        allow(job).to receive(:sleep)

        job.perform(correlation_id, user_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "registration_channel_#{user_id}",
          { response: { "status" => "success", "email" => "test@example.com" } }
        )
      end
    end
  end

  describe '#broadcast_response' do
    let(:job) { described_class.new }

    it 'transforms snake_case keys to camelCase' do
      response = { "first_name" => "John", "last_name" => "Doe" }

      job.send(:broadcast_response, user_id, response)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "registration_channel_#{user_id}",
        { response: { "firstName" => "John", "lastName" => "Doe" } }
      )
    end
  end
end
