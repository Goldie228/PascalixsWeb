require 'rails_helper'

RSpec.describe CodeValidityJob, type: :job do
  let(:redis_instance) { instance_double(Redis) }
  let(:message_callback) { {} }

  before do
    allow(Redis).to receive(:new).and_return(redis_instance)
    allow(ActionCable.server).to receive(:broadcast)

    # Захватываем subscribe блок для эмуляции сообщений
    allow(redis_instance).to receive(:subscribe).with("code_validity_updates") do |&block|
      # Создаём мок обработчика подписки
      handler = double("on")
      allow(handler).to receive(:message) do |&msg_block|
        message_callback[:block] = msg_block
      end
      block.call(handler)
    end
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when a valid message is received' do
      it 'broadcasts the validity status to the user channel' do
        job.perform

        # Эмулируем получение сообщения
        message = { user_id: "123", valid: true }.to_json
        message_callback[:block].call("code_validity_updates", message)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "code_validation_status_123",
          { success: true }
        )
      end

      it 'broadcasts false when code is invalid' do
        job.perform

        message = { user_id: "456", valid: false }.to_json
        message_callback[:block].call("code_validity_updates", message)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "code_validation_status_456",
          { success: false }
        )
      end
    end

    context 'when an invalid JSON message is received' do
      it 'logs the error and does not broadcast' do
        job.perform

        expect(Rails.logger).to receive(:error).with(/Ошибка парсинга/)
        message_callback[:block].call("code_validity_updates", "invalid json")

        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end

    context 'when a Redis connection error occurs' do
      it 'logs the error and retries' do
        call_count = 0
        allow(Redis).to receive(:new) do
          call_count += 1
          if call_count == 1
            raise Redis::CannotConnectError.new("Connection refused")
          else
            redis_instance
          end
        end
        expect(Rails.logger).to receive(:error).with(/Ошибка в CodeValidityJob/)

        job.perform
      end
    end
  end
end
