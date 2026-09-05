require 'rails_helper'

RSpec.describe EmailChannel, type: :channel do
  let(:user_id) { '42' }

  before do
    stub_connection
  end

  describe '#subscribed' do
    it 'subscribes to a stream named email:{user_id}' do
      subscribe(user_id: user_id)
      expect(subscription).to have_stream_from("email:#{user_id}")
    end

    it 'interpolates different user_ids into distinct stream names' do
      subscribe(user_id: '77')
      expect(subscription).to have_stream_from('email:77')
    end

    it 'enqueues EmailUpdateJob with the user_id' do
      expect(EmailUpdateJob).to receive(:perform_async).with(user_id)
      subscribe(user_id: user_id)
    end
  end

  describe 'stream setup' do
    it 'creates a stream for email updates' do
      subscribe(user_id: user_id)
      expect(subscription.streams).to include("email:#{user_id}")
    end
  end
end
