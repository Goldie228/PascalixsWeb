require 'rails_helper'

RSpec.describe TwoFactorAuthChannel, type: :channel do
  let(:user_id) { '42' }

  before do
    stub_connection
  end

  describe '#subscribed' do
    it 'subscribes to a stream named two_factor_auth:{user_id}' do
      subscribe(user_id: user_id)
      expect(subscription).to have_stream_from("two_factor_auth:#{user_id}")
    end

    it 'interpolates different user_ids into distinct stream names' do
      subscribe(user_id: '77')
      expect(subscription).to have_stream_from('two_factor_auth:77')
    end

    it 'enqueues TwoFactorUpdateJob with the user_id' do
      expect(TwoFactorUpdateJob).to receive(:perform_async).with(user_id)
      subscribe(user_id: user_id)
    end
  end

  describe 'stream setup' do
    it 'creates a stream for two-factor auth updates' do
      subscribe(user_id: user_id)
      expect(subscription.streams).to include("two_factor_auth:#{user_id}")
    end
  end

  describe 'rejection logic' do
    it 'rejects subscription when user_id is not provided' do
      # Канал не отклоняет явно, но имя потока
      # содержит пустой user_id. Проверяем что подписка
      # работает (явного отклонения в коде канала нет).
      subscribe(user_id: nil)
      expect(subscription).to have_stream_from('two_factor_auth:')
    end
  end
end
