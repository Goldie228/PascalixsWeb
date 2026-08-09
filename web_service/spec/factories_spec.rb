require 'rails_helper'

RSpec.describe 'Factories' do
  describe 'user factory' do
    it 'is valid' do
      user = build(:user)
      expect(user).to be_valid
      expect(user.email).to be_present
      expect(user.username).to be_present
    end

    it 'generates unique emails' do
      users = Array.new(3) { build(:user) }
      emails = users.map(&:email)
      expect(emails.uniq.length).to eq(3)
    end

    it 'supports :without_registration trait' do
      user = build(:user, :without_registration)
      expect(user.is_registered).to be false
    end
  end

  describe 'user_proxy factory' do
    before do
      # Redis.current удалён в redis 5.x, но модель всё ещё использует его.
      unless Redis.respond_to?(:current)
        Redis.define_singleton_method(:current) { @current_instance }
        Redis.define_singleton_method(:current=) { |v| @current_instance = v }
      end
      redis_stub = instance_double('Redis')
      Redis.current = redis_stub
      allow(redis_stub).to receive(:hgetall).and_return({})
      allow(redis_stub).to receive(:multi).and_yield
      allow(redis_stub).to receive(:hset)
      allow(redis_stub).to receive(:expire)
    end

    it 'is valid' do
      proxy = build(:user_proxy)
      expect(proxy).to be_a(UserProxy)
      expect(proxy.id).to be_present
    end

    it 'supports :as_self trait' do
      proxy = build(:user_proxy, :as_self)
      current_id = proxy.instance_variable_get(:@current_user_id)
      expect(current_id).to eq(proxy.id)
    end

    it 'supports :with_cached_email trait' do
      proxy = build(:user_proxy, :with_cached_email)
      expect(proxy.email).to be_present
    end

    it 'supports :with_cached_username trait' do
      proxy = build(:user_proxy, :with_cached_username)
      expect(proxy.username).to be_present
    end
  end
end
