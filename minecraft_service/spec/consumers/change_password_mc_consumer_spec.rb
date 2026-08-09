require 'rails_helper'

RSpec.describe ChangePasswordMcConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  let(:message) { double('Karafka::Messages::Message', payload: kafka_payload) }

  before do
    allow(consumer).to receive(:messages).and_return([message])
  end

  describe '#consume' do
    context 'when message contains valid nickname and password as nested payload' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve', 'password' => 'new_hashed_password' } }
      end
      let!(:authme) { create(:authme, realname: 'Steve', password: 'old_hash') }

      it 'updates the Authme record password' do
        consumer.consume

        expect(authme.reload.password).to eq('new_hashed_password')
      end

      it 'finds the record by realname' do
        consumer.consume

        expect(Authme.find_by(realname: 'Steve').password).to eq('new_hashed_password')
      end
    end

    context 'when payload is a JSON string' do
      let(:kafka_payload) do
        { 'payload' => { nickname: 'Steve', password: 'json_string_hash' }.to_json }
      end
      let!(:authme) { create(:authme, realname: 'Steve', password: 'old_hash') }

      it 'parses the JSON string and updates the password' do
        consumer.consume

        expect(authme.reload.password).to eq('json_string_hash')
      end
    end

    context 'when payload is at the top level (no nested payload key)' do
      let(:kafka_payload) do
        { 'nickname' => 'Steve', 'password' => 'top_level_hash' }
      end
      let!(:authme) { create(:authme, realname: 'Steve', password: 'old_hash') }

      it 'uses the top-level payload and updates the password' do
        consumer.consume

        expect(authme.reload.password).to eq('top_level_hash')
      end
    end

    context 'when player does not exist in Authme' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'NonExistent', 'password' => 'some_hash' } }
      end

      it 'does not raise an error' do
        expect { consumer.consume }.not_to raise_error
      end

      it 'does not create a new record' do
        expect { consumer.consume }.not_to change(Authme, :count)
      end
    end

    context 'when nickname is missing' do
      let(:kafka_payload) do
        { 'payload' => { 'password' => 'some_hash' } }
      end

      it 'skips processing without errors' do
        expect { consumer.consume }.not_to raise_error
      end

      it 'does not update any records' do
        authme = create(:authme, realname: 'Steve', password: 'old_hash')

        consumer.consume

        expect(authme.reload.password).to eq('old_hash')
      end
    end

    context 'when password is missing' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve' } }
      end

      it 'skips processing without errors' do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when both required fields are missing' do
      let(:kafka_payload) do
        { 'payload' => { 'unrelated_field' => 'value' } }
      end

      it 'skips processing without errors' do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when payload is nil' do
      let(:kafka_payload) { {} }

      it 'handles nil payload gracefully' do
        # payload["payload"] возвращает nil — пропускаем
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when payload is an invalid JSON string' do
      let(:kafka_payload) do
        { 'payload' => 'not valid json{' }
      end

      it 'rescues JSON::ParserError and does not raise' do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when payload is an unprocessable type' do
      let(:kafka_payload) do
        { 'payload' => 12345 }
      end

      it 'skips processing without errors' do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when Authme update fails validation' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve', 'password' => 'new_hash' } }
      end
      let!(:authme) { create(:authme, realname: 'Steve', password: 'old_hash') }

      it 'rescues ActiveRecord::RecordInvalid and does not raise' do
        allow_any_instance_of(Authme).to receive(:update!)
          .and_raise(ActiveRecord::RecordInvalid.new(authme))

        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when nickname has surrounding whitespace' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => '  Steve  ', 'password' => 'trimmed_hash' } }
      end
      let!(:authme) { create(:authme, realname: 'Steve', password: 'old_hash') }

      it 'strips whitespace before looking up the record' do
        consumer.consume

        expect(authme.reload.password).to eq('trimmed_hash')
      end
    end

    context 'with multiple messages' do
      let(:message2) { double('Karafka::Messages::Message', payload: kafka_payload2) }
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve', 'password' => 'hash1' } }
      end
      let(:kafka_payload2) do
        { 'payload' => { 'nickname' => 'Alex', 'password' => 'hash2' } }
      end
      let!(:authme_steve) { create(:authme, realname: 'Steve', password: 'old1') }
      let!(:authme_alex) { create(:authme, realname: 'Alex', password: 'old2') }

      before do
        allow(consumer).to receive(:messages).and_return([message, message2])
      end

      it 'processes each message and updates both records' do
        consumer.consume

        expect(authme_steve.reload.password).to eq('hash1')
        expect(authme_alex.reload.password).to eq('hash2')
      end
    end
  end
end
