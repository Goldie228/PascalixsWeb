require 'rails_helper'

RSpec.describe RolesConsumer, type: :consumer do
  subject(:consumer) { described_class.new }

  # Мок Karafka-сообщения
  let(:message) { double('Karafka::Messages::Message', payload: kafka_payload) }

  before do
    # Заглушка messages enumerable в consumer
    allow(consumer).to receive(:messages).and_return([message])
    # Заглушка REDIS_CLIENT
    stub_const('REDIS_CLIENT', double('Redis'))
    allow(REDIS_CLIENT).to receive(:set)
    allow(REDIS_CLIENT).to receive(:exists?).and_return(false)
    allow(REDIS_CLIENT).to receive(:del)
  end

  describe '#consume' do
    context 'when message contains a valid nickname with roles' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve' } }
      end

      let(:uuid) { 'a1b2c3d4-e5f6-7890-abcd-ef0000000001' }
      let(:roles_result) do
        { 100 => { system_name: 'admin', name: 'Admin', color: '#AA0000' } }
      end

      it 'looks up player UUID by username' do
        allow(LuckpermsPlayer).to receive(:find_uuid_by_username)
          .with('steve').and_return(uuid)
        allow(LuckpermsUserPermission).to receive(:player_prefixes)
          .with(uuid).and_return(['admin'])
        allow(LuckpermsGroupPermission).to receive(:translate_and_sort_prefixes)
          .with(['admin']).and_return(roles_result)
        allow(LuckpermsGroup).to receive(:merge_colors)
          .with(roles_result).and_return(roles_result)

        consumer.consume

        expect(LuckpermsPlayer).to have_received(:find_uuid_by_username).with('steve')
      end

      it 'sends roles to Redis with correct key and JSON payload' do
        allow(LuckpermsPlayer).to receive(:find_uuid_by_username)
          .with('steve').and_return(uuid)
        allow(LuckpermsUserPermission).to receive(:player_prefixes)
          .with(uuid).and_return(['admin'])
        allow(LuckpermsGroupPermission).to receive(:translate_and_sort_prefixes)
          .with(['admin']).and_return(roles_result)
        allow(LuckpermsGroup).to receive(:merge_colors)
          .with(roles_result).and_return(roles_result)

        consumer.consume

        expect(REDIS_CLIENT).to have_received(:set).with(
          'player_roles:steve',
          roles_result.to_json
        )
      end
    end

    context 'when message contains a nickname with no roles found' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'UnknownPlayer' } }
      end

      before do
        allow(LuckpermsPlayer).to receive(:find_uuid_by_username)
          .with('unknownplayer').and_return(nil)
      end

      it 'removes roles from Redis when player has no UUID' do
        allow(REDIS_CLIENT).to receive(:exists?)
          .with('player_roles:unknownplayer').and_return(true)

        consumer.consume

        expect(REDIS_CLIENT).to have_received(:del).with('player_roles:unknownplayer')
      end

      it 'does not attempt to delete when key does not exist in Redis' do
        allow(REDIS_CLIENT).to receive(:exists?)
          .with('player_roles:unknownplayer').and_return(false)

        consumer.consume

        expect(REDIS_CLIENT).not_to have_received(:del)
      end
    end

    context 'when nickname is blank' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => '  ' } }
      end

      it 'skips processing and does not query the database' do
        expect(LuckpermsPlayer).not_to receive(:find_uuid_by_username)

        consumer.consume
      end

      it 'does not interact with Redis' do
        consumer.consume

        expect(REDIS_CLIENT).not_to have_received(:set)
        expect(REDIS_CLIENT).not_to have_received(:del)
      end
    end

    context 'when nickname is missing from payload' do
      let(:kafka_payload) do
        { 'payload' => {} }
      end

      it 'skips processing without errors' do
        expect(LuckpermsPlayer).not_to receive(:find_uuid_by_username)

        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when payload key is missing entirely' do
      let(:kafka_payload) { {} }

      it 'handles missing payload gracefully' do
        # payload["payload"] возвращает nil — nil["nickname"] выбрасывает NoMethodError
        # ловится rescue блоком
        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when player has UUID but no prefixes' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve' } }
      end
      let(:uuid) { 'a1b2c3d4-e5f6-7890-abcd-ef0000000001' }

      it 'removes roles from Redis when prefixes are empty' do
        allow(LuckpermsPlayer).to receive(:find_uuid_by_username)
          .with('steve').and_return(uuid)
        allow(LuckpermsUserPermission).to receive(:player_prefixes)
          .with(uuid).and_return([])
        allow(REDIS_CLIENT).to receive(:exists?)
          .with('player_roles:steve').and_return(true)

        consumer.consume

        expect(REDIS_CLIENT).to have_received(:del).with('player_roles:steve')
      end
    end

    context 'when a database error occurs' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve' } }
      end

      it 'rescues the error and continues processing' do
        allow(LuckpermsPlayer).to receive(:find_uuid_by_username)
          .and_raise(ActiveRecord::ConnectionNotEstablished)

        expect { consumer.consume }.not_to raise_error
      end
    end

    context 'when nickname has mixed case' do
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => '  Steve  ' } }
      end
      let(:uuid) { 'a1b2c3d4-e5f6-7890-abcd-ef0000000001' }
      let(:roles_result) do
        { 10 => { system_name: 'vip', name: 'VIP', color: '#FFAA00' } }
      end

      it 'strips whitespace and downcases for lookups' do
        allow(LuckpermsPlayer).to receive(:find_uuid_by_username)
          .with('steve').and_return(uuid)
        allow(LuckpermsUserPermission).to receive(:player_prefixes)
          .with(uuid).and_return(['vip'])
        allow(LuckpermsGroupPermission).to receive(:translate_and_sort_prefixes)
          .with(['vip']).and_return(roles_result)
        allow(LuckpermsGroup).to receive(:merge_colors)
          .with(roles_result).and_return(roles_result)

        consumer.consume

        expect(REDIS_CLIENT).to have_received(:set).with(
          'player_roles:steve',
          roles_result.to_json
        )
      end
    end

    context 'with multiple messages' do
      let(:message2) { double('Karafka::Messages::Message', payload: kafka_payload2) }
      let(:kafka_payload) do
        { 'payload' => { 'nickname' => 'Steve' } }
      end
      let(:kafka_payload2) do
        { 'payload' => { 'nickname' => 'Alex' } }
      end

      before do
        allow(consumer).to receive(:messages).and_return([message, message2])
        allow(LuckpermsPlayer).to receive(:find_uuid_by_username).and_return(nil)
        allow(REDIS_CLIENT).to receive(:exists?).and_return(false)
      end

      it 'processes each message independently' do
        consumer.consume

        expect(LuckpermsPlayer).to have_received(:find_uuid_by_username).with('steve')
        expect(LuckpermsPlayer).to have_received(:find_uuid_by_username).with('alex')
      end
    end
  end
end
