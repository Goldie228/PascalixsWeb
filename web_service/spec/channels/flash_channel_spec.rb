require 'rails_helper'

RSpec.describe FlashChannel, type: :channel do
  before do
    stub_connection
  end

  describe '#subscribed' do
    it 'subscribes to the static flash_channel stream' do
      subscribe
      expect(subscription).to have_stream_from('flash_channel')
    end

    it 'does not require any params' do
      subscribe
      expect(subscription.streams).to include('flash_channel')
    end
  end

  describe 'stream setup' do
    it 'creates a stream for flash messages' do
      subscribe
      expect(subscription.streams).to include('flash_channel')
    end
  end
end
