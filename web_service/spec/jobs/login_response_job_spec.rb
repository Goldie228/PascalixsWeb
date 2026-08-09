require 'rails_helper'

RSpec.describe LoginResponseJob, type: :job do
  let(:correlation_id) { "corr_abc123" }
  let(:redis_instance) { instance_double(Redis) }
  let(:message_callback) { {} }

  before do
    allow(Redis).to receive(:new).and_return(redis_instance)
    allow(redis_instance).to receive(:close)
    allow(ActionCable.server).to receive(:broadcast)

    # Захватываем subscribe блок
    allow(redis_instance).to receive(:subscribe).with("auth_responses:#{correlation_id}") do |&block|
      handler = double("on")
      allow(handler).to receive(:message) do |&msg_block|
        message_callback[:block] = msg_block
      end
      block.call(handler)
    end
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when a response is received within timeout' do
      it 'broadcasts the response with camelCase keys' do
        # Эмулируем получение сообщения
        allow(redis_instance).to receive(:subscribe) do |&block|
          handler = double("on")
          allow(handler).to receive(:message) do |&msg_block|
            msg = { status: "success", user_id: "123" }.to_json
            msg_block.call("auth_responses:#{correlation_id}", msg)
          end
          block.call(handler)
        end

        allow(redis_instance).to receive(:unsubscribe)

        job.perform(correlation_id)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "login_channel_#{correlation_id}",
          { response: { "status" => "success", "userId" => "123" } }
        )
      end
    end

    context 'when timeout occurs' do
      it 'logs an error and does not broadcast' do
        allow(redis_instance).to receive(:subscribe) do
          raise Timeout::Error, "execution expired"
        end

        expect(Rails.logger).to receive(:error).with(/Timeout waiting for message/)

        job.perform(correlation_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end

    context 'when no response is received' do
      it 'logs a timeout error' do
        # Эмулируем subscribe без сообщения
        allow(redis_instance).to receive(:subscribe) do |&block|
          handler = double("on")
          allow(handler).to receive(:message) # no message sent
          block.call(handler)
        end

        # Принудительный таймаут через Timeout.timeout
        allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)

        expect(Rails.logger).to receive(:error).with(/Timeout waiting for message/)

        job.perform(correlation_id)

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end
  end

  describe '#broadcast_response' do
    let(:job) { described_class.new }

    it 'transforms keys to camelCase' do
      response = { "user_name" => "john", "is_active" => true }

      job.send(:broadcast_response, correlation_id, response)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "login_channel_#{correlation_id}",
        { response: { "userName" => "john", "isActive" => true } }
      )
    end
  end
end
