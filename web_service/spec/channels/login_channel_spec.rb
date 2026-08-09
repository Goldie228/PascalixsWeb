require 'rails_helper'

RSpec.describe LoginChannel, type: :channel do
  let(:correlation_id) { 'abc-123-def' }

  before do
    stub_connection
  end

  describe '#subscribed' do
    it 'subscribes to a stream named login_channel_{correlation_id}' do
      subscribe(correlation_id: correlation_id)
      expect(subscription).to have_stream_from("login_channel_#{correlation_id}")
    end

    it 'interpolates different correlation_ids into distinct stream names' do
      subscribe(correlation_id: 'xyz-789')
      expect(subscription).to have_stream_from('login_channel_xyz-789')
    end

    it 'logs the correlation_id on subscription' do
      expect(Rails.logger).to receive(:info).with(/LoginChannel.*#{correlation_id}/)
      subscribe(correlation_id: correlation_id)
    end
  end

  describe 'stream setup' do
    it 'creates a stream for login updates' do
      subscribe(correlation_id: correlation_id)
      expect(subscription.streams).to include("login_channel_#{correlation_id}")
    end
  end
end
