require 'rails_helper'

RSpec.describe ChangePassStatusConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  let(:message) { double('Karafka::Messages::Message', payload: kafka_payload) }
  let(:roles_consumer) { instance_double(RolesConsumer) }

  before do
    allow(consumer).to receive(:messages).and_return([message])
    # Заглушка REDIS_CLIENT
    stub_const('REDIS_CLIENT', double('Redis'))
    allow(REDIS_CLIENT).to receive(:set)
    allow(REDIS_CLIENT).to receive(:exists?).and_return(false)
    allow(REDIS_CLIENT).to receive(:del)
    # Заглушка RolesConsumer внутри consumer
    allow(RolesConsumer).to receive(:new).and_return(roles_consumer)
    allow(roles_consumer).to receive(:get_player_roles).and_return(nil)
    allow(roles_consumer).to receive(:send_roles_to_redis)
    allow(roles_consumer).to receive(:remove_roles_from_redis)
  end

  describe '#consume' do
    context 'when pass is true (adding player to Authme)' do
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => true,
            'password' => '$2a$10$hashedpassword'
          }
        }
      end

      it 'creates a new Authme record' do
        expect { consumer.consume }.to change(Authme, :count).by(1)
      end

      it 'sets correct attributes on the new record' do
        consumer.consume

        record = Authme.find_by(realname: 'Steve')
        expect(record).to be_present
        expect(record.username).to eq('steve')
        expect(record.password).to eq('$2a$10$hashedpassword')
        expect(record.world).to eq('world')
        expect(record.x).to eq(0.0)
        expect(record.y).to eq(0.0)
        expect(record.z).to eq(0.0)
      end

      it 'updates an existing Authme record if player already exists' do
        create(:authme, realname: 'Steve', password: 'old_hash')

        expect { consumer.consume }.not_to change(Authme, :count)

        record = Authme.find_by(realname: 'Steve')
        expect(record.password).to eq('$2a$10$hashedpassword')
      end

      it 'updates roles in Redis after adding player' do
        allow(roles_consumer).to receive(:get_player_roles)
          .with('Steve').and_return({ 10 => { system_name: 'vip', name: 'VIP', color: '#FFAA00' } })

        consumer.consume

        expect(roles_consumer).to have_received(:send_roles_to_redis)
          .with('Steve', { 10 => { system_name: 'vip', name: 'VIP', color: '#FFAA00' } })
      end

      it 'removes roles from Redis when player has no roles' do
        allow(roles_consumer).to receive(:get_player_roles)
          .with('Steve').and_return(nil)

        consumer.consume

        expect(roles_consumer).to have_received(:remove_roles_from_redis).with('Steve')
      end
    end

    context 'when pass is true but password hash is blank' do
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => true,
            'password' => ''
          }
        }
      end

      it 'skips processing and does not create a record' do
        expect { consumer.consume }.not_to change(Authme, :count)
      end
    end

    context 'when pass is true but password key is missing' do
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => true
          }
        }
      end

      it 'skips processing because hash is blank (nil)' do
        expect { consumer.consume }.not_to change(Authme, :count)
      end
    end

    context 'when pass is false (removing player from Authme)' do
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => false
          }
        }
      end

      context 'when player exists in Authme' do
        let!(:authme) { create(:authme, realname: 'Steve') }

        it 'deletes the Authme record' do
          expect { consumer.consume }.to change(Authme, :count).by(-1)
        end

        it 'removes roles from Redis after deletion' do
          allow(roles_consumer).to receive(:get_player_roles)
            .with('Steve').and_return(nil)

          consumer.consume

          expect(roles_consumer).to have_received(:remove_roles_from_redis).with('Steve')
        end
      end

      context 'when player does not exist in Authme' do
        it 'does not raise an error' do
          expect { consumer.consume }.not_to raise_error
        end

        it 'still attempts to update roles' do
          consumer.consume

          expect(roles_consumer).to have_received(:get_player_roles).with('Steve')
        end
      end
    end

    context 'when pass is a string "true"' do
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => 'true',
            'password' => '$2a$10$hashedpassword'
          }
        }
      end

      it 'casts string "true" to boolean true and creates record' do
        expect { consumer.consume }.to change(Authme, :count).by(1)
      end
    end

    context 'when pass is a string "false"' do
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => 'false'
          }
        }
      end
      let!(:authme) { create(:authme, realname: 'Steve') }

      it 'casts string "false" to boolean false and deletes record' do
        expect { consumer.consume }.to change(Authme, :count).by(-1)
      end
    end

    context 'when payload is a JSON string' do
      let(:kafka_payload) do
        json = { nickname: 'Steve', pass: false }.to_json
        { 'payload' => json }
      end
      let!(:authme) { create(:authme, realname: 'Steve') }

      it 'parses the JSON string and processes correctly' do
        expect { consumer.consume }.to change(Authme, :count).by(-1)
      end
    end

    context 'when payload is at the top level (no nested payload key)' do
      let(:kafka_payload) do
        { 'nickname' => 'Steve', 'pass' => false }
      end
      let!(:authme) { create(:authme, realname: 'Steve') }

      it 'uses the top-level payload and processes correctly' do
        expect { consumer.consume }.to change(Authme, :count).by(-1)
      end
    end

    context 'when nickname is missing' do
      let(:kafka_payload) do
        { 'payload' => { 'pass' => true, 'password' => 'hash' } }
      end

      it 'skips processing without errors' do
        expect { consumer.consume }.not_to raise_error
      end

      it 'does not create any records' do
        expect { consumer.consume }.not_to change(Authme, :count)
      end
    end

    context 'when pass is missing' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve' } }
      end

      it 'skips processing without errors' do
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when nickname is blank' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => '  ', 'pass' => true, 'password' => 'hash' } }
      end

      it 'skips processing without creating a record' do
        expect { consumer.consume }.not_to change(Authme, :count)
      end
    end

    context 'when payload is nil' do
      let(:kafka_payload) { {} }

      it 'handles nil payload gracefully' do
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

    context 'when Authme save fails validation' do
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => true,
            'password' => 'hash'
          }
        }
      end

      it 'rescues ActiveRecord::RecordInvalid and does not raise' do
        allow_any_instance_of(Authme).to receive(:save!)
          .and_raise(ActiveRecord::RecordInvalid.new(Authme.new))

        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when roles update raises an error' do
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => false
          }
        }
      end

      it 'rescues the error from RolesConsumer gracefully' do
        allow(roles_consumer).to receive(:get_player_roles)
          .and_raise(ActiveRecord::ConnectionNotEstablished)

        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'with multiple messages' do
      let(:message2) { double('Karafka::Messages::Message', payload: kafka_payload2) }
      let(:kafka_payload) do
        {
          'payload' => {
            'nickname' => 'Steve',
            'pass' => true,
            'password' => 'hash1'
          }
        }
      end
      let(:kafka_payload2) do
        {
          'payload' => {
            'nickname' => 'Alex',
            'pass' => false
          }
        }
      end
      let!(:authme_alex) { create(:authme, realname: 'Alex') }

      before do
        allow(consumer).to receive(:messages).and_return([message, message2])
      end

      it 'processes each message independently' do
        consumer.consume

        expect(Authme.find_by(realname: 'Steve')).to be_present
        expect(Authme.find_by(realname: 'Alex')).to be_nil
      end

      it 'updates roles for each player' do
        consumer.consume

        expect(roles_consumer).to have_received(:get_player_roles).with('Steve')
        expect(roles_consumer).to have_received(:get_player_roles).with('Alex')
      end
    end
  end
end
