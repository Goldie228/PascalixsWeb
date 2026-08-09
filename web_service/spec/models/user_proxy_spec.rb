require 'rails_helper'

RSpec.describe UserProxy do
  # UserProxy — PORO, без БД.
  # Тесты проверяют method_missing делегацию, Redis кеширование и AuthClient HTTP.

  let(:user_id) { SecureRandom.uuid }
  let(:current_user_id) { user_id }
  let(:payload) { { 'user_id' => user_id, 'cached' => {} } }

  subject(:proxy) { described_class.new(payload, current_user_id: current_user_id) }

  before do
    # Redis.current удалён в redis 5.x, но модель всё ещё использует его.
    # Определяем class-level accessor для verify_partial_doubles.
    unless Redis.respond_to?(:current)
      Redis.define_singleton_method(:current) { @current_instance }
      Redis.define_singleton_method(:current=) { |v| @current_instance = v }
    end

    @redis_stub = instance_double('Redis')
    Redis.current = @redis_stub
    allow(@redis_stub).to receive(:hgetall).and_return({})
    allow(@redis_stub).to receive(:multi).and_yield
    allow(@redis_stub).to receive(:hset)
    allow(@redis_stub).to receive(:expire)

    # Заглушка HTTP-вызовов AuthClient
    allow(AuthClient).to receive(:get)
  end

  describe '#initialize' do
    it 'extracts user_id from payload' do
      expect(proxy.id).to eq(user_id)
    end

    it 'handles nil payload gracefully' do
      proxy = described_class.new(nil)
      expect(proxy.id).to be_nil
    end

    it 'accepts cached data from payload' do
      payload_with_cache = { 'user_id' => user_id, 'cached' => { 'email' => 'cached@test.com' } }
      proxy = described_class.new(payload_with_cache)
      expect(proxy.email).to eq('cached@test.com')
    end
  end

  describe '#id' do
    it 'returns the user_id from the payload' do
      expect(proxy.id).to eq(user_id)
    end
  end

  describe '#method_missing — cache-first lookup' do
    context 'when data is in the initial cached payload' do
      let(:payload) { { 'user_id' => user_id, 'cached' => { 'email' => 'from_payload@test.com' } } }

      it 'returns cached value without calling AuthClient' do
        expect(proxy.email).to eq('from_payload@test.com')
        expect(AuthClient).not_to have_received(:get)
      end
    end

    context 'when data is in Redis' do
      before do
        allow(@redis_stub).to receive(:hgetall)
          .with("user:#{user_id}:cache")
          .and_return({ 'username' => 'from_redis' })
      end

      it 'merges Redis cache and returns the value' do
        expect(proxy.username).to eq('from_redis')
        expect(AuthClient).not_to have_received(:get)
      end
    end
  end

  describe '#method_missing — fetching from AuthClient' do
    context 'when user requests their own data (current_user)' do
      let(:current_user_id) { user_id }

      it 'calls /api/v1/me/fields' do
        allow(AuthClient).to receive(:get)
          .with('/api/v1/me/fields', query: { fields: [:email] })
          .and_return({ 'email' => 'me@test.com' })

        expect(proxy.email).to eq('me@test.com')
      end
    end

    context 'when user requests another users data' do
      let(:other_user_id) { SecureRandom.uuid }
      let(:current_user_id) { SecureRandom.uuid }
      let(:payload) { { 'user_id' => other_user_id, 'cached' => {} } }

      it 'calls /api/v1/users/:id/fields' do
        allow(AuthClient).to receive(:get)
          .with("/api/v1/users/#{other_user_id}/fields", query: { fields: [:email] })
          .and_return({ 'email' => 'other@test.com' })

        expect(proxy.email).to eq('other@test.com')
      end
    end

    context 'for special field mappings' do
      it 'maps discord_account to :discord field' do
        allow(AuthClient).to receive(:get)
          .with('/api/v1/me/fields', query: { fields: [:discord] })
          .and_return({ 'discord_account' => 'discord_user#1234' })

        expect(proxy.discord_account).to eq('discord_user#1234')
      end

      it 'maps minecraft_account to :minecraft field' do
        allow(AuthClient).to receive(:get)
          .with('/api/v1/me/fields', query: { fields: [:minecraft] })
          .and_return({ 'minecraft_account' => 'steve' })

        expect(proxy.minecraft_account).to eq('steve')
      end

      it 'maps update to :updated_at field' do
        allow(AuthClient).to receive(:get)
          .with('/api/v1/me/fields', query: { fields: [:updated_at] })
          .and_return({ 'update' => '2026-01-01T00:00:00Z' })

        expect(proxy.update).to eq('2026-01-01T00:00:00Z')
      end
    end
  end

  describe 'caching after fetch' do
    it 'writes fetched value to Redis with TTL' do
      allow(AuthClient).to receive(:get)
        .with('/api/v1/me/fields', query: { fields: [:email] })
        .and_return({ 'email' => 'new@test.com' })

      expect(@redis_stub).to receive(:multi)
      expect(@redis_stub).to receive(:hset).with("user:#{user_id}:cache", 'email', '"new@test.com"')
      expect(@redis_stub).to receive(:expire).with("user:#{user_id}:cache", 300)

      proxy.email
    end
  end

  describe 'error handling' do
    context 'when user_id is blank' do
      let(:payload) { { 'user_id' => nil, 'cached' => {} } }

      it 'raises ArgumentError' do
        expect { proxy.email }.to raise_error(ArgumentError, /User ID is required/)
      end
    end

    context 'when AuthClient returns a response without the requested key' do
      it 'returns nil and logs an error' do
        allow(AuthClient).to receive(:get)
          .with('/api/v1/me/fields', query: { fields: [:email] })
          .and_return({ 'other_field' => 'value' })

        expect(Rails.logger).to receive(:error).with(/Failed to fetch field email/)
        expect(proxy.email).to be_nil
      end
    end

    context 'when AuthClient returns nil' do
      it 'returns nil and logs an error' do
        allow(AuthClient).to receive(:get)
          .with('/api/v1/me/fields', query: { fields: [:email] })
          .and_return(nil)

        expect(Rails.logger).to receive(:error).with(/Failed to fetch field email/)
        expect(proxy.email).to be_nil
      end
    end
  end

  describe 'factory' do
    it 'builds a valid UserProxy via FactoryBot' do
      proxy = build(:user_proxy)
      expect(proxy).to be_a(UserProxy)
      expect(proxy.id).to be_present
    end

    it 'supports :as_self trait' do
      proxy = build(:user_proxy, :as_self)
      expect(proxy.instance_variable_get(:@current_user_id)).to eq(proxy.id)
    end

    it 'supports :with_cached_email trait' do
      proxy = build(:user_proxy, :with_cached_email)
      expect(proxy.email).to be_present
    end
  end
end
